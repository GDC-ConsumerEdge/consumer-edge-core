#! /bin/bash
# Copyright 2023 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Take in 1 parameter (the name of the new build-artifacts Post-Fix Folder to use)

PREFIX_DIR=$(dirname -- "$0")
source ${PREFIX_DIR}/install-shell-helper.sh

MARKER="*"

want_new_folder=false
desired_folder="build-artifacts-example" # Default desired_folder
list_folders=true
generate_yaml=""

function usage() {
    pretty_print "Usage: instance-context.sh [-c] [-l] [-g <yaml_file>] [folder-name]"
    pretty_print "  Change or generate the active build-artifacts folder to use during an instance run.\n"
    pretty_print "  folder-name\tThe name of the build-artifacts folder to use (Optional)"
    pretty_print "\n  Options/Flags:"
    pretty_print "  -h\t\tPrint this help message (optional)"
    pretty_print "  -c\t\tPrint the current context (optional)"
    pretty_print "  -l\t\tList available contexts (optional)"
    pretty_print "  -g file\tGenerate a new context from the provided YAML file"
}

function check_options() {
    has_option=false
    while getopts "chlg:" flag; do
        case "${flag}" in
        c) print_context; list_folders=false; has_option=true ;;
        l) list_folders=true; has_option=true ;;
        g) generate_yaml="${OPTARG}"; list_folders=false; has_option=true ;;
        h) usage; exit 0 ;;
        esac
    done

    shift "$((OPTIND-1))"
    if [[ ! -z "$1" ]]; then
        if [[ $has_option == false || -n "$generate_yaml" ]]; then
            desired_folder=$1
            want_new_folder=true
        fi
    fi
}

function get_list_of_folders() {
    local folders=$(ls -d ./build-artifacts-*)
    declare -a output=()

    for folder in $folders; do
        # Remove the "build-artifacts-" prefix
        fld="${folder#"./build-artifacts-"}"
        output+=( "$fld" )
    done

    echo "${output[@]}" # "${users[@]}"
}

function display_folders() {
    local active=""

    pretty_print "Available Instance Run Contexts\n=============================="

    if [[ ! -z "$1" ]]; then
        active=$1
    fi

    folders=$(get_list_of_folders)

    for folder in $folders; do
        # Add a marker to the active folder
        if [[ $folder == $active ]]; then
            line="${folder}${MARKER}"
            pretty_print "${line}" "INFO"
        else
            pretty_print $folder
        fi

    done

}

function get_active_folder() {

    current_folder=$(readlink build-artifacts)

    if [[ ! -z "${current_folder}" ]]; then
        current_folder=${current_folder#"build-artifacts-"}
    fi

    echo $current_folder
}

function print_context() {
    pretty_print "\nContext Details"
    pretty_print "=============="
    pretty_print "GCP Project ID:\t\t${PROJECT_ID}"
    pretty_print "GCP Region & Zone:\t${REGION} / ${ZONE}"
    pretty_print "ACM Cluster Name:\t${CLUSTER_ACM_NAME}"
    pretty_print "Primary Root Repo:\t${ROOT_REPO_URL}"
    echo "" # blank line
}

function generate_context() {
    local yaml_file="$1"
    
    if ! command -v yq &> /dev/null; then
        pretty_print "Error: 'yq' is required. Please install it." "ERROR"
        exit 1
    fi
    if [[ ! -f "$yaml_file" ]]; then
        pretty_print "Error: YAML file '$yaml_file' not found." "ERROR"
        exit 1
    fi

    local ctx_name=$(yq e '.context_name' "$yaml_file")
    local cl_name=$(yq e '.cluster_name' "$yaml_file")
    local p_id=$(yq e '.project_id' "$yaml_file")
    local reg=$(yq e '.region // "us-central1"' "$yaml_file")
    local zn=$(yq e '.zone // "us-central1-a"' "$yaml_file")
    local cp_vip=$(yq e '.control_plane_vip' "$yaml_file")
    local in_vip=$(yq e '.ingress_vip' "$yaml_file")
    local lb_pool=$(yq e '.load_balancer_pool_cidr' "$yaml_file")

    if [[ -z "$ctx_name" || "$ctx_name" == "null" ]]; then
        pretty_print "Error: 'context_name' required in YAML." "ERROR"
        exit 1
    fi

    local target="build-artifacts-${ctx_name}"
    if [[ -d "$target" ]]; then
        pretty_print "Error: Directory '$target' already exists." "ERROR"
        exit 1
    fi

    pretty_print "Generating $target..." "INFO"
    cp -r build-artifacts-example "$target"

    # 1. Update envrc
    mv "$target/envrc-example" "$target/envrc" 2>/dev/null || true
    if [[ ! -f "$target/envrc" ]]; then
        cp templates/envrc-template.sh "$target/envrc"
    fi
    
    sed -i "1i # This file sets environment variables for the cluster provisioning run." "$target/envrc"
    sed -i "s/export PROJECT_ID=\"\${PROJECT_ID}\"/export PROJECT_ID=\"${p_id}\" # GCP Project ID (from YAML project_id)/" "$target/envrc"
    sed -i "s/export REGION=\"us-central1\"/export REGION=\"${reg}\" # GCP Region (from YAML region)/" "$target/envrc"
    sed -i "s/export ZONE=\"us-central1-a\"/export ZONE=\"${zn}\" # GCP Zone (from YAML zone)/" "$target/envrc"
    sed -i "s/export CLUSTER_ACM_NAME=\"gdc-demo\"/export CLUSTER_ACM_NAME=\"${cl_name}\" # Cluster name used by ACM (from YAML cluster_name)/" "$target/envrc"

    # 2. Update inventory.yaml
    mv "$target/inventory-example.yaml" "$target/inventory.yaml" 2>/dev/null || true
    if [[ ! -f "$target/inventory.yaml" ]]; then
        cp templates/inventory-physical-example.yaml "$target/inventory.yaml"
    fi

    # Rename root key and update basic vars
    yq e -i "
      .[\"${cl_name}_cluster\"] = .[\"[[ cluster-name]]_cluster\"] |
      del(.[\"[[ cluster-name]]_cluster\"]) |
      .[\"${cl_name}_cluster\"].vars.cluster_name = \"${cl_name}\" |
      .[\"${cl_name}_cluster\"].vars.acm_cluster_name = \"${cl_name}\" |
      .[\"${cl_name}_cluster\"].vars.control_plane_vip = \"${cp_vip}\" |
      .[\"${cl_name}_cluster\"].vars.ingress_vip = \"${in_vip}\" |
      .[\"${cl_name}_cluster\"].vars.load_balancer_pool_cidr = [\"${lb_pool}\"] |
      del(.[\"${cl_name}_cluster\"].hosts) |
      .[\"${cl_name}_cluster\"].hosts = {} |
      del(.[\"${cl_name}_cluster\"].vars.peer_node_ips) |
      .[\"${cl_name}_cluster\"].vars.peer_node_ips = []
    " "$target/inventory.yaml"

    # Add comments to inventory.yaml fields using yq head comments if possible, but simpler to use sed for blocks
    sed -i "/cluster_name: \"${cl_name}\"/s/$/ # Name of the cluster (from YAML cluster_name)/" "$target/inventory.yaml"
    sed -i "/control_plane_vip: \"${cp_vip}\"/s/$/ # K8s API endpoint (from YAML control_plane_vip)/" "$target/inventory.yaml"
    sed -i "/ingress_vip: \"${in_vip}\"/s/$/ # Entry point for services (from YAML ingress_vip)/" "$target/inventory.yaml"

    # Parse nodes for inventory hosts
    local num_nodes=$(yq e '.nodes | length' "$yaml_file")
    
    # Overwrite add-hosts completely
    echo "# Edge Servers for ${ctx_name} (Auto-generated from YAML nodes)" > "$target/add-hosts"
    echo "# Used for local DNS resolution to cluster nodes." >> "$target/add-hosts"

    for (( i=0; i<$num_nodes; i++ )); do
        local n_name=$(yq e ".nodes[$i].name" "$yaml_file")
        local n_ip=$(yq e ".nodes[$i].ip" "$yaml_file")
        
        # Add to inventory hosts
        yq e -i ".[\"${cl_name}_cluster\"].hosts.\"${n_name}\".node_ip = \"${n_ip}\" |
                 .[\"${cl_name}_cluster\"].hosts.\"${n_name}\".machine_label = \"{{ inventory_hostname }}\" |
                 .[\"${cl_name}_cluster\"].hosts.\"${n_name}\".ansible_host = \"{{ node_ip }}\"" "$target/inventory.yaml"
        
        # Identify first node as primary
        if [ $i -eq 0 ]; then
            yq e -i ".[\"${cl_name}_cluster\"].hosts.\"${n_name}\".primary_cluster_machine = true" "$target/inventory.yaml"
        fi

        # Add to peer_node_ips list
        yq e -i ".[\"${cl_name}_cluster\"].vars.peer_node_ips += [\"${n_ip}\"]" "$target/inventory.yaml"
        
        # Add to add-hosts
        echo "$n_ip    $n_name" >> "$target/add-hosts"
    done

    # 3. Rename instance-run-vars
    mv "$target/instance-run-vars-example.yaml" "$target/instance-run-vars.yaml" 2>/dev/null || true
    if [[ ! -f "$target/instance-run-vars.yaml" ]]; then
        cp templates/instance-run-vars-template.yaml "$target/instance-run-vars.yaml"
    fi
    sed -i "1i # Variables specific to this provisioning run (e.g. storage provider)" "$target/instance-run-vars.yaml"

    # 4. Generate SSH Keys
    ssh-keygen -t rsa -b 4096 -f "$target/consumer-edge-machine" -N "" -q
    
    pretty_print "Context $ctx_name generated." "INFO"
    pretty_print "ACTION REQUIRED:" "INFO"
    pretty_print "1. Add provisioning-gsa.json to $target (GSA key with Editor permissions)" "INFO"
    pretty_print "2. Add node-gsa.json to $target (GSA key for cluster nodes)" "INFO"
    exit 0
}

#### Main Execution

check_options "$@"

if [[ -n "$generate_yaml" ]]; then
    generate_context "$generate_yaml"
fi

# Change the active folder if -l used
if [[ ${want_new_folder} == true ]]; then
    # check if the desired folder is the same as the current
    active=$(get_active_folder)
    if [[ $desired_folder == $active ]]; then
        pretty_print "Current context is already ${active}, no action will be taken" "DEBUG"
        print_context
    else
        # check to see if the desired folder is in the list of folders, if not, offer to create a new context

        available_folders=$(get_list_of_folders)

        found=false
        for f in $available_folders; do
            if [[ $f == $desired_folder ]]; then
                found=true
                break
            fi
        done

        # Case: if the desired folder is not found, ask to create it
        if [[ $found == false ]]; then
            pretty_print "The desired context '${desired_folder}' does not exist, would you like to create it? (y/n)"
            read answer
            if [[ $answer == "y" ]]; then
                pretty_print "Creating new context ${desired_folder}"
                # create new folder from example
                cp -r build-artifacts-example build-artifacts-${desired_folder}
                # remove old build-artifacts link
                rm -rf build-artifacts
                # Create new build-artifacts link
                ln -s build-artifacts-${desired_folder} build-artifacts
                echo "Please modify the files for the context before using it in a provisioning run" "INFO"
            else
                pretty_print "No action taken" "ERROR"
                exit 0
            fi
        else # Case: if the desired folder is found, change the context
            pretty_print "Setting Context to '${desired_folder}'" "INFO"
            rm -rf build-artifacts
            ln -s build-artifacts-${desired_folder} build-artifacts
            if [[ -x "$(command -v direnv)" ]]; then
                direnv allow .
            else
                pretty_print "direnv not installed, perhaps you should 'source .envrc'"
            fi

            pretty_print "Don't forget to check your gcloud current config"
        fi
    fi

fi

if [[ $list_folders == true ]]; then

    active_folder=$(get_active_folder)

    display_folders ${active_folder}
fi