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
want_open=false
want_close=false
ingest_folder=""

function usage() {
    pretty_print "Usage: instance-context.sh [-c] [-l] [-g <yaml_file>] [-i <folder>] [-o] [-x] [folder-name]"
    pretty_print "  Change, generate, or ingest a build-artifacts folder to use during an instance run.\n"
    pretty_print "  folder-name\tThe name of the build-artifacts folder to use (Optional)"
    pretty_print "\n  Options/Flags:"
    pretty_print "  -h\t\tPrint this help message (optional)"
    pretty_print "  -c\t\tPrint the current context (optional)"
    pretty_print "  -l\t\tList available contexts (optional)"
    pretty_print "  -g file\tGenerate a new context from the provided YAML file"
    pretty_print "  -i folder\tIngest an existing folder into GSM (one-time migration)"
    pretty_print "  -o\t\tOpen (Hydrate) the current context from GSM"
    pretty_print "  -x\t\tClose (Dehydrate) the context (wipes secrets from disk)"
}

function check_options() {
    has_option=false
    while getopts "chlg:i:ox" flag; do
        case "${flag}" in
        c) print_context; list_folders=false; has_option=true ;;
        l) list_folders=true; has_option=true ;;
        g) generate_yaml="${OPTARG}"; list_folders=false; has_option=true ;;
        i) ingest_folder="${OPTARG}"; list_folders=false; has_option=true ;;
        o) want_open=true; list_folders=false; has_option=true ;;
        x) want_close=true; list_folders=false; has_option=true ;;
        h) usage; exit 0 ;;
        esac
    done

    shift "$((OPTIND-1))"
    if [[ ! -z "$1" ]]; then
        if [[ $has_option == false || -n "$generate_yaml" || -n "$ingest_folder" || $want_open == true || $want_close == true ]]; then
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

function gsm_get() {
    local secret_name="$1"
    local p_id="$2"
    gcloud secrets versions access latest --secret="${secret_name}" --project="${p_id}" 2>/dev/null
}

function gsm_put() {
    local secret_name="$1"
    local secret_value="$2"
    local cl_name="$3"
    local p_id="$4"
    
    if ! gcloud secrets describe "${secret_name}" --project="${p_id}" &>/dev/null; then
        local labels=""
        if [[ -n "$cl_name" ]]; then
            # GSM labels must be lowercase, alphanumeric, hyphens or underscores
            local label_val=$(echo "$cl_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/_/g')
            labels="--labels=cluster=$label_val"
        fi
        gcloud secrets create "${secret_name}" --replication-policy="automatic" ${labels} --project="${p_id}"
    fi
    echo -n "${secret_value}" | gcloud secrets versions add "${secret_name}" --data-file=- --project="${p_id}"
}

function dehydrate_context() {
    local target_dir="$1"
    if [[ -z "$target_dir" || "$target_dir" == "." ]]; then 
        target_dir="build-artifacts"
    fi
    
    if [[ ! -L "$target_dir" && ! -d "$target_dir" ]]; then
        pretty_print "Target $target_dir not found" "ERROR"
        return
    fi

    pretty_print "Closing context in $target_dir..." "INFO"
    
    # 1. Wipe sensitive files
    rm -f "$target_dir/consumer-edge-machine"
    rm -f "$target_dir/consumer-edge-machine.pub"
    rm -f "$target_dir/provisioning-gsa.json"
    rm -f "$target_dir/node-gsa.json"
    
    # 2. Scrub envrc
    if [[ -f "$target_dir/envrc" ]]; then
        local closed="****closed*******"
        sed -i "s/.*SCM_TOKEN_USER=.*/export SCM_TOKEN_USER=\"$closed\"/" "$target_dir/envrc"
        sed -i "s/.*SCM_TOKEN_TOKEN=.*/export SCM_TOKEN_TOKEN=\"$closed\"/" "$target_dir/envrc"
        sed -i "s/.*OIDC_CLIENT_ID=.*/export OIDC_CLIENT_ID=\"$closed\"/" "$target_dir/envrc"
        sed -i "s/.*OIDC_CLIENT_SECRET=.*/export OIDC_CLIENT_SECRET=\"$closed\"/" "$target_dir/envrc"
    fi
}

function ensure_gsa_key() {
    local target_file="$1"
    local secret_name="$2"
    local cl_name="$3"
    local p_id="$4"
    local sa_description="$5"

    # Try to fetch from GSM first
    local key_content=$(gsm_get "$secret_name" "$p_id")
    
    if [[ -n "$key_content" ]]; then
        echo "$key_content" > "$target_file"
        return 0
    fi

    # Not in GSM, check local filesystem
    if [[ -f "$target_file" ]]; then
        # If local but missing in GSM, push it
        gsm_put "$secret_name" "$(cat "$target_file")" "$cl_name" "$p_id"
        return 0
    fi

    # Missing in both, prompt user
    pretty_print "$sa_description key ('$target_file') not found in GSM or locally." "WARN"
    echo -n "Would you like to create a new key for a Google Service Account? (y/n): "
    read answer
    if [[ "$answer" == "y" ]]; then
        echo -n "Enter the Service Account email for $sa_description: "
        read sa_email
        if [[ -n "$sa_email" ]]; then
            gcloud iam service-accounts keys create "$target_file" \
                --iam-account="$sa_email" \
                --project="$p_id"
            
            if [[ $? -eq 0 ]]; then
                gsm_put "$secret_name" "$(cat "$target_file")" "$cl_name" "$p_id"
                pretty_print "Successfully created and uploaded $sa_description." "INFO"
            else
                pretty_print "Failed to create Service Account key." "ERROR"
            fi
        fi
    fi
}

function hydrate_context() {
    local target_dir="$1"
    if [[ -z "$target_dir" || "$target_dir" == "." ]]; then 
        target_dir="build-artifacts"
    fi

    if [[ ! -f "$target_dir/envrc" ]]; then
        pretty_print "Error: $target_dir/envrc not found. Cannot hydrate." "ERROR"
        return
    fi

    # Extract metadata from envrc
    local cl_name=$(grep "export CLUSTER_ACM_NAME=" "$target_dir/envrc" | cut -d'"' -f2)
    local p_id=$(grep "export PROJECT_ID=" "$target_dir/envrc" | cut -d'"' -f2)
    
    if [[ -z "$cl_name" ]]; then
        pretty_print "Error: Could not find CLUSTER_ACM_NAME in $target_dir/envrc" "ERROR"
        return
    fi
    if [[ -z "$p_id" ]]; then
        pretty_print "Error: Could not find PROJECT_ID in $target_dir/envrc" "ERROR"
        return
    fi

    pretty_print "Opening context for cluster $cl_name in project $p_id..." "INFO"

    # Fetch/Ensure Files
    gsm_get "gdc-${cl_name}-ssh-key" "$p_id" > "$target_dir/consumer-edge-machine"
    chmod 600 "$target_dir/consumer-edge-machine"
    gsm_get "gdc-${cl_name}-ssh-key-pub" "$p_id" > "$target_dir/consumer-edge-machine.pub"
    
    ensure_gsa_key "$target_dir/provisioning-gsa.json" "gdc-${cl_name}-prov-gsa" "$cl_name" "$p_id" "Provisioning GSA"
    ensure_gsa_key "$target_dir/node-gsa.json" "gdc-${cl_name}-node-gsa" "$cl_name" "$p_id" "Node GSA"

    # Fetch envrc vars
    local scm_user=$(gsm_get "gdc-${cl_name}-scm-user" "$p_id")
    local scm_token=$(gsm_get "gdc-${cl_name}-scm-token" "$p_id")
    local oidc_id=$(gsm_get "gdc-${cl_name}-oidc-id" "$p_id")
    local oidc_secret=$(gsm_get "gdc-${cl_name}-oidc-secret" "$p_id")

    # Inject into envrc
    if [[ -n "$scm_user" ]]; then sed -i "s/.*SCM_TOKEN_USER=.*/export SCM_TOKEN_USER=\"$scm_user\"/" "$target_dir/envrc"; fi
    if [[ -n "$scm_token" ]]; then sed -i "s/.*SCM_TOKEN_TOKEN=.*/export SCM_TOKEN_TOKEN=\"$scm_token\"/" "$target_dir/envrc"; fi
    if [[ -n "$oidc_id" ]]; then sed -i "s/.*OIDC_CLIENT_ID=.*/export OIDC_CLIENT_ID=\"$oidc_id\"/" "$target_dir/envrc"; fi
    if [[ -n "$oidc_secret" ]]; then sed -i "s/.*OIDC_CLIENT_SECRET=.*/export OIDC_CLIENT_SECRET=\"$oidc_secret\"/" "$target_dir/envrc"; fi

    pretty_print "Context hydrated successfully." "INFO"
    
    # Summary
    pretty_print "Summary" "INFO"
    pretty_print "======================================="
    pretty_print "GCP Project ID:   $p_id"
    pretty_print "SCM User Secret:  ${scm_user:-NOT SET}"
    pretty_print "SCM Token Secret: $(mask_secret "$scm_token")"
    pretty_print "Provisioning GSA: $(get_gsa_email_from_secret "gdc-${cl_name}-prov-gsa" "$p_id")"
    pretty_print "Node GSA:         $(get_gsa_email_from_secret "gdc-${cl_name}-node-gsa" "$p_id")"
    echo ""
    pretty_print "Context $cl_name State: [opened]" "INFO"
}

function ingest_context() {
    local name="$1"
    local target_dir="build-artifacts-${name}"
    
    if [[ ! -d "$target_dir" ]]; then
        pretty_print "Error: Directory '$target_dir' not found." "ERROR"
        exit 1
    fi

    if [[ ! -f "$target_dir/envrc" ]]; then
        pretty_print "Error: $target_dir/envrc not found. Cannot ingest." "ERROR"
        exit 1
    fi

    # Extract metadata
    local cl_name=$(grep "export CLUSTER_ACM_NAME=" "$target_dir/envrc" | cut -d'"' -f2)
    local p_id=$(grep "export PROJECT_ID=" "$target_dir/envrc" | cut -d'"' -f2)

    if [[ -z "$cl_name" || -z "$p_id" ]]; then
        pretty_print "Error: CLUSTER_ACM_NAME and PROJECT_ID must be set in envrc for ingestion." "ERROR"
        exit 1
    fi

    pretty_print "Ingesting $name into project $p_id (cluster: $cl_name)..." "INFO"

    # 1. Ingest Files
    if [[ -f "$target_dir/consumer-edge-machine" ]]; then
        gsm_put "gdc-${cl_name}-ssh-key" "$(cat "$target_dir/consumer-edge-machine")" "$cl_name" "$p_id"
    fi
    if [[ -f "$target_dir/consumer-edge-machine.pub" ]]; then
        gsm_put "gdc-${cl_name}-ssh-key-pub" "$(cat "$target_dir/consumer-edge-machine.pub")" "$cl_name" "$p_id"
    fi
    if [[ -f "$target_dir/provisioning-gsa.json" ]]; then
        gsm_put "gdc-${cl_name}-prov-gsa" "$(cat "$target_dir/provisioning-gsa.json")" "$cl_name" "$p_id"
    fi
    if [[ -f "$target_dir/node-gsa.json" ]]; then
        gsm_put "gdc-${cl_name}-node-gsa" "$(cat "$target_dir/node-gsa.json")" "$cl_name" "$p_id"
    fi

    # 2. Ingest Vars
    local scm_user=$(grep "export SCM_TOKEN_USER=" "$target_dir/envrc" | cut -d'"' -f2)
    local scm_token=$(grep "export SCM_TOKEN_TOKEN=" "$target_dir/envrc" | cut -d'"' -f2)
    local oidc_id=$(grep "export OIDC_CLIENT_ID=" "$target_dir/envrc" | cut -d'"' -f2)
    local oidc_secret=$(grep "export OIDC_CLIENT_SECRET=" "$target_dir/envrc" | cut -d'"' -f2)

    if [[ -n "$scm_user" && "$scm_user" != "****closed*******" ]]; then gsm_put "gdc-${cl_name}-scm-user" "$scm_user" "$cl_name" "$p_id"; fi
    if [[ -n "$scm_token" && "$scm_token" != "****closed*******" ]]; then gsm_put "gdc-${cl_name}-scm-token" "$scm_token" "$cl_name" "$p_id"; fi
    if [[ -n "$oidc_id" && "$oidc_id" != "****closed*******" ]]; then gsm_put "gdc-${cl_name}-oidc-id" "$oidc_id" "$cl_name" "$p_id"; fi
    if [[ -n "$oidc_secret" && "$oidc_secret" != "****closed*******" ]]; then gsm_put "gdc-${cl_name}-oidc-secret" "$oidc_secret" "$cl_name" "$p_id"; fi

    # 3. Secure the folder
    dehydrate_context "$target_dir"
    
    pretty_print "Ingestion complete for $name." "INFO"

    # Summary
    pretty_print "Summary" "INFO"
    pretty_print "======================================="
    pretty_print "GCP Project ID:   $p_id"
    pretty_print "SCM User Secret:  ${scm_user:-NOT SET}"
    pretty_print "SCM Token Secret: $(mask_secret "$scm_token")"
    pretty_print "Provisioning GSA: $(get_gsa_email_from_secret "gdc-${cl_name}-prov-gsa" "$p_id")"
    pretty_print "Node GSA:         $(get_gsa_email_from_secret "gdc-${cl_name}-node-gsa" "$p_id")"
    echo ""
    pretty_print "Context $name State: [closed]" "INFO"
}

function mask_secret() {
    local val="$1"
    if [[ -z "$val" || "$val" == "null" ]]; then echo "MISSING"; return; fi
    if [[ "$val" == "****closed*******" ]]; then echo "$val"; return; fi
    if [[ ${#val} -le 6 ]]; then echo "******"; return; fi
    echo "${val:0:3}-***********-${val: -3}"
}

function get_gsa_email_from_secret() {
    local secret_name="$1"
    local p_id="$2"
    local content=$(gsm_get "$secret_name" "$p_id")
    if [[ -n "$content" ]]; then
        local email=$(echo "$content" | jq -r '.client_email' 2>/dev/null)
        if [[ -n "$email" && "$email" != "null" ]]; then
            echo "$email"
        else
            echo "[GSM: $secret_name]"
        fi
    else
        echo "[MISSING]"
    fi
}

function print_gsm_examples() {
    local cl_name="$1"
    local p_id="$2"
    shift 2
    local missing=("$@")

    pretty_print "\nHow to fix missing secrets:" "INFO"
    pretty_print "======================================="
    
    for item in "${missing[@]}"; do
        case "$item" in
            "scm-user")
                echo "# Create Git Username Secret"
                echo "gcloud secrets create gdc-${cl_name}-scm-user --project=\"$p_id\" --labels=\"cluster=$cl_name\" --replication-policy=\"automatic\""
                echo "echo -n \"YOUR_GIT_USERNAME\" | gcloud secrets versions add gdc-${cl_name}-scm-user --project=\"$p_id\" --data-file=-"
                ;;
            "scm-token")
                echo "# Create Git Token Secret"
                echo "gcloud secrets create gdc-${cl_name}-scm-token --project=\"$p_id\" --labels=\"cluster=$cl_name\" --replication-policy=\"automatic\""
                echo "echo -n \"YOUR_GIT_TOKEN\" | gcloud secrets versions add gdc-${cl_name}-scm-token --project=\"$p_id\" --data-file=-"
                ;;
            "prov-gsa")
                echo "# Create Provisioning GSA Key Secret (Upload your JSON key file)"
                echo "gcloud secrets create gdc-${cl_name}-prov-gsa --project=\"$p_id\" --labels=\"cluster=$cl_name\" --replication-policy=\"automatic\""
                echo "gcloud secrets versions add gdc-${cl_name}-prov-gsa --project=\"$p_id\" --data-file=path/to/provisioning-gsa.json"
                ;;
            "node-gsa")
                echo "# Create Node GSA Key Secret (Upload your JSON key file)"
                echo "gcloud secrets create gdc-${cl_name}-node-gsa --project=\"$p_id\" --labels=\"cluster=$cl_name\" --replication-policy=\"automatic\""
                echo "gcloud secrets versions add gdc-${cl_name}-node-gsa --project=\"$p_id\" --data-file=path/to/node-gsa.json"
                ;;
        esac
        echo ""
    done
    
    pretty_print "Once secrets are created in GSM, re-run this command." "INFO"
}

function validate_gsm_secret() {
    local secret_name="$1"
    local p_id="$2"
    if gcloud secrets describe "${secret_name}" --project="${p_id}" &>/dev/null; then
        echo "OK"
    else
        echo "MISSING"
    fi
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
    local action="create"
    if [[ -d "$target" ]]; then
        action="update"
    fi

    # 1. Validating Secrets
    pretty_print "1. Validating Secrets" "INFO"
    pretty_print "======================================="
    pretty_print "Google Project ID: [$p_id]"
    pretty_print "YAML Config File: [$yaml_file]"
    
    local scm_user_status=$(validate_gsm_secret "gdc-${cl_name}-scm-user" "$p_id")
    local scm_token_status=$(validate_gsm_secret "gdc-${cl_name}-scm-token" "$p_id")
    local prov_gsa_status=$(validate_gsm_secret "gdc-${cl_name}-prov-gsa" "$p_id")
    local node_gsa_status=$(validate_gsm_secret "gdc-${cl_name}-node-gsa" "$p_id")
    
    pretty_print "SCM User Secret:  [$scm_user_status]"
    pretty_print "SCM Token Secret: [$scm_token_status]"
    pretty_print "Prov GSA Secret:  [$prov_gsa_status]"
    pretty_print "Node GSA Secret:  [$node_gsa_status]"
    echo ""

    local missing=()
    if [[ "$scm_user_status" == "MISSING" ]]; then missing+=("scm-user"); fi
    if [[ "$scm_token_status" == "MISSING" ]]; then missing+=("scm-token"); fi
    
    # Only stop for GSAs if they also don't exist locally
    if [[ "$prov_gsa_status" == "MISSING" && ! -f "$target/provisioning-gsa.json" ]]; then missing+=("prov-gsa"); fi
    if [[ "$node_gsa_status" == "MISSING" && ! -f "$target/node-gsa.json" ]]; then missing+=("node-gsa"); fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        pretty_print "STOP: Missing required secrets in GSM." "ERROR"
        print_gsm_examples "$cl_name" "$p_id" "${missing[@]}"
        exit 1
    fi

    # 2. Display Settings
    pretty_print "2. Display Settings" "INFO"
    pretty_print "======================================="
    
    local scm_user_val=$(gsm_get "gdc-${cl_name}-scm-user" "$p_id")
    local scm_token_val=$(gsm_get "gdc-${cl_name}-scm-token" "$p_id")
    local prov_gsa_email=$(get_gsa_email_from_secret "gdc-${cl_name}-prov-gsa" "$p_id")
    local node_gsa_email=$(get_gsa_email_from_secret "gdc-${cl_name}-node-gsa" "$p_id")
    
    pretty_print "SCM User Secret:  ${scm_user_val:-NOT SET}"
    pretty_print "SCM Token Secret: $(mask_secret "$scm_token_val")"
    pretty_print "Provisioning GSA: $prov_gsa_email"
    pretty_print "Node GSA:         $node_gsa_email"
    pretty_print "Cluster:   $cl_name"
    pretty_print "Region/Zone: $reg / $zn"
    echo ""

    # 3. Ready to [create | update] context?
    pretty_print "3. Ready to $action context '$ctx_name'? (y/N)"
    read answer
    if [[ "$answer" != "y" ]]; then
        pretty_print "Aborted." "WARN"
        exit 0
    fi

    pretty_print "Generating $target in project $p_id..." "INFO"
    
    if [[ "$action" == "create" ]]; then
        cp -r build-artifacts-example "$target"
    fi

    # ... rest of generation logic (envrc, inventory, etc) ...
    # (I will keep the existing implementation but wrap it in this UX)

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
    rm -f "$target/add-hosts-example"
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
    
    # 5. Ensure GSA keys are handled (prompt if missing)
    ensure_gsa_key "$target/provisioning-gsa.json" "gdc-${cl_name}-prov-gsa" "$cl_name" "$p_id" "Provisioning GSA"
    ensure_gsa_key "$target/node-gsa.json" "gdc-${cl_name}-node-gsa" "$cl_name" "$p_id" "Node GSA"

    # 6. Push SSH to GSM and start CLOSED
    gsm_put "gdc-${cl_name}-ssh-key" "$(cat "$target/consumer-edge-machine")" "${cl_name}" "${p_id}"
    gsm_put "gdc-${cl_name}-ssh-key-pub" "$(cat "$target/consumer-edge-machine.pub")" "${cl_name}" "${p_id}"
    
    dehydrate_context "$target"

    # 4. Summary
    pretty_print "4. Summary" "INFO"
    pretty_print "======================================="
    pretty_print "GCP Project ID:   $p_id"
    pretty_print "SCM User Secret:  ${scm_user_val:-NOT SET}"
    pretty_print "SCM Token Secret: $(mask_secret "$scm_token_val")"
    pretty_print "Provisioning GSA: $prov_gsa_email"
    pretty_print "Node GSA:         $node_gsa_email"
    echo ""

    # 5. Context State
    local state="closed"
    if [[ -f "$target/consumer-edge-machine" && -f "$target/provisioning-gsa.json" ]]; then
        state="opened"
    fi
    # If it was just dehydrated, it should be closed.
    
    pretty_print "5. Context $ctx_name State: [$state]" "INFO"
    echo ""
    pretty_print "Happy clustering!" "SUCCESS"
    exit 0
}

#### Main Execution

check_options "$@"

if [[ -n "$generate_yaml" ]]; then
    generate_context "$generate_yaml"
fi

if [[ -n "$ingest_folder" ]]; then
    ingest_context "$ingest_folder"
fi

if [[ $want_close == true && $want_new_folder == true ]]; then
    # Wipe secrets from current context before switching
    dehydrate_context "build-artifacts"
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

if [[ $want_open == true ]]; then
    hydrate_context "build-artifacts"
fi

if [[ $want_close == true && $want_new_folder == false ]]; then
    dehydrate_context "build-artifacts"
fi

if [[ $list_folders == true ]]; then

    active_folder=$(get_active_folder)

    display_folders ${active_folder}
fi