#! /bin/bash
# Copyright 2026 Google LLC
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

ACTION="SWITCH" # Default
CONTEXT_NAME=""
YAML_FILE=""
INGEST_DIR=""
FORCED_REGION=""
VERBOSE="false"

function usage() {
    pretty_print "Usage: instance-context.sh [-c name] [-d name] [-g file] [-l] [-o] [-x] [-i name] [-r region] [-v] [context-name]"
    pretty_print "  Manage build-artifacts contexts for instance runs.\n"
    pretty_print "  context-name\tThe name of the context to switch to (Optional)"
    pretty_print "\n  Options/Flags:"
    pretty_print "  -h, --help\tPrint this help message"
    pretty_print "  -v, --verbose\tEnable verbose output for errors"
    pretty_print "  -c name\tCreate a new context with the given name"
    pretty_print "  -d name\tDownload a context configuration from GSM"
    pretty_print "  -g file\tGenerate a new context from a local YAML configuration"
    pretty_print "  -l\t\tList available contexts"
    pretty_print "  -o\t\tOpen (Hydrate) the current context from GSM"
    pretty_print "  -x\t\tClose (Dehydrate) the context (wipes secrets)"
    pretty_print "  -i name\tIngest an existing directory (build-artifacts-<name>) into GSM"
    pretty_print "  -r region\tForce regional operations (also --force-regional)"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c) ACTION="CREATE"; shift; CONTEXT_NAME="$1"; shift ;;
        -d) ACTION="DOWNLOAD"; shift; CONTEXT_NAME="$1"; shift ;;
        -g) ACTION="GENERATE"; shift; YAML_FILE="$1"; shift ;;
        -o) ACTION="OPEN"; shift ;;
        -x) ACTION="CLOSE"; shift ;;
        -i) ACTION="INGEST"; shift; INGEST_DIR="$1"; shift ;;
        -l) ACTION="LIST"; shift ;;
        -r|--force-regional) FORCED_REGION="$2"; shift 2 ;;
        -v|--verbose) VERBOSE="true"; shift ;;
        -h|--help) usage; exit 0 ;;
        -*) echo "Unknown option: $1"; usage; exit 1 ;;
        *) CONTEXT_NAME="$1"; shift ;;
    esac
done

function get_list_of_folders() {
    local folders=$(ls -d ./build-artifacts-*)
    declare -a output=()

    for folder in $folders; do
        # Remove the "build-artifacts-" prefix
        fld="${folder#"./build-artifacts-"}"
        if [[ "$fld" != "example" ]]; then output+=( "$fld" ); fi
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

    local max_len=0
    for folder in $folders; do
        local len=${#folder}
        if [[ $folder == $active ]]; then
            ((len+=1))
        fi
        if [[ $len -gt $max_len ]]; then
            max_len=$len
        fi
    done
    ((max_len+=4))

    for folder in $folders; do
        local state="[CLOSED]"
        local color="DEFAULT"
        local target_dir="build-artifacts-${folder}"

        if ls "$target_dir"/*-example 1> /dev/null 2>&1; then
            state="[INCOMPLETE]"
            color="ERROR"
        elif [[ -f "$target_dir/consumer-edge-machine" ]]; then
            state="[OPENED]"
        fi

        local display_name="$folder"
        if [[ $folder == $active ]]; then
            display_name="${folder}${MARKER}"
            if [[ "$state" == "[OPENED]" ]]; then
                color="SUCCESS"
            elif [[ "$state" == "[CLOSED]" ]]; then
                color="WARN"
            fi
        fi

        printf -v padded_name "%-*s" $max_len "$display_name"
        if [[ $folder == $active ]]; then
            printf "${BOLD}"
            pretty_print "${padded_name}${state}" "$color"
            printf "${ENDCOLOR}"
        else
            pretty_print "${padded_name}${state}" "$color"
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
    # Try to source the envrc of the active context to ensure variables are populated
    local current=$(get_active_folder)
    if [[ -n "$current" && -f "build-artifacts-${current}/envrc" ]]; then
        source "build-artifacts-${current}/envrc" >/dev/null 2>&1
    fi

    pretty_print "\nContext Details"
    pretty_print "=============="
    pretty_print "GCP Project ID:\t\t${PROJECT_ID}"
    pretty_print "GCP Region & Zone:\t${REGION} / ${ZONE}"
    pretty_print "ACM Cluster Name:\t${CLUSTER_ACM_NAME}"
    pretty_print "Primary Root Repo:\t${ROOT_REPO_URL} (${ROOT_REPO_BRANCH:-main})"
    echo "" # blank line
}

function get_secret() {
    local secret_key="$1"    # e.g., "scm_user"
    local gsm_name="$2"      # e.g., "gdc-my-cluster-scm-user"
    local is_required="$3"   # "true" or "false"
    local p_id="$4"
    local reg="$5"
    local ctx_name="$6"

    # 1. Check Local Override File
    local override_file="configs/context-${ctx_name}-secrets.yaml"
    if [[ -f "$override_file" ]]; then
        local val=$(yq e ".${secret_key}" "$override_file")
        if [[ "$val" != "null" ]]; then
            # Found in override! Push to GSM if missing or different
            gsm_put "$gsm_name" "$val" "" "$p_id" "$reg"
            echo "$val"
            return 0
        fi
    fi

    # 2. Check GSM
    local gsm_val=$(gsm_get "$gsm_name" "$p_id" "$reg")
    if [[ -n "$gsm_val" ]]; then
        echo "$gsm_val"
        return 0
    fi

    # 3. Interactive Prompt (only if required)
    if [[ "$is_required" == "true" ]]; then
        local value1=""
        local value2=""
        while true; do
            pretty_print "Enter value for ${secret_key}: " "INPUT"
            read -s value1
            pretty_print "Confirm value for ${secret_key}: " "INPUT"
            read -s value2
            if [[ "$value1" == "$value2" && -n "$value1" ]]; then
                gsm_put "$gsm_name" "$value1" "" "$p_id" "$reg"
                echo "$value1"
                return 0
            else
                pretty_print "Values do not match or are empty. Try again." "ERROR"
            fi
        done
    fi

    echo ""
}

function gsm_get() {
    local secret_name="$1"
    local p_id="$2"
    local reg="$3"

    local val=""
    if [[ -n "$FORCED_REGION" ]]; then
        val=$(gcloud secrets versions access latest --secret="${secret_name}" --project="${p_id}" --location="${FORCED_REGION}" 2>/dev/null)
    else
        val=$(gcloud secrets versions access latest --secret="${secret_name}" --project="${p_id}" 2>/dev/null || gcloud secrets versions access latest --secret="${secret_name}" --project="${p_id}" --location="${reg}" 2>/dev/null)
    fi
    echo "$val"
}

function gsm_put() {
    local secret_name="$1"
    local secret_value="$2"
    local cl_name="$3"
    local p_id="$4"
    local reg="$5"

    local labels=""
    if [[ -n "$cl_name" ]]; then
        # GSM labels must be lowercase, alphanumeric, hyphens or underscores
        local label_val=$(echo "$cl_name" | tr '[:upper:]' '[:lower:]' | awk '{gsub(/[^a-z0-9_-]/, "_"); print}')
        labels="--labels=cluster=$label_val"
    fi

    if ! { gcloud secrets describe "${secret_name}" --project="${p_id}" &>/dev/null || gcloud secrets describe "${secret_name}" --project="${p_id}" --location="${reg}" &>/dev/null; }; then
        if [[ -n "$FORCED_REGION" ]]; then
             local create_out
             if ! create_out=$(gcloud secrets create "${secret_name}" --replication-policy="user-managed" --locations="${FORCED_REGION}" ${labels} --project="${p_id}" 2>&1); then
                 pretty_print "Failed to create regional secret '${secret_name}' in ${FORCED_REGION}." "ERROR"
                 if [[ "$VERBOSE" == "true" ]]; then
                     pretty_print "Error details: ${create_out}" "ERROR"
                 fi
                 return 1
             fi
        else
            local create_global_out
            if ! create_global_out=$(gcloud secrets create "${secret_name}" --replication-policy="automatic" ${labels} --project="${p_id}" 2>&1); then
                 if [[ -n "$reg" ]]; then
                     local create_reg_out
                     if ! create_reg_out=$(gcloud secrets create "${secret_name}" --replication-policy="user-managed" --locations="${reg}" ${labels} --project="${p_id}" 2>&1); then
                         pretty_print "Failed to create secret '${secret_name}' globally and regionally. Check permissions." "ERROR"
                         if [[ "$VERBOSE" == "true" ]]; then
                             pretty_print "Global attempt error: ${create_global_out}" "ERROR"
                             pretty_print "Regional attempt error: ${create_reg_out}" "ERROR"
                         fi
                         return 1
                     fi
                 else
                     pretty_print "Failed to create secret '${secret_name}' globally and no region provided. Check permissions." "ERROR"
                     if [[ "$VERBOSE" == "true" ]]; then
                         pretty_print "Error details: ${create_global_out}" "ERROR"
                     fi
                     return 1
                 fi
            fi
        fi
    fi

    # Check if we need to skip update because value is identical
    local current_val=$(gsm_get "${secret_name}" "${p_id}" "${reg}")
    if [[ "$current_val" == "$secret_value" ]]; then
        return 0
    fi

    if ! echo -n "${secret_value}" | gcloud secrets versions add "${secret_name}" --data-file=- --project="${p_id}" 2>/dev/null; then
        echo -n "${secret_value}" | gcloud secrets versions add "${secret_name}" --data-file=- --project="${p_id}" --location="${reg}" >/dev/null
    fi
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
        awk -v closed="$closed" '{
            if ($0 ~ /SCM_TOKEN_USER=/) {
                prefix = ($0 ~ /^#/) ? "# " : ""
                $0 = prefix "export SCM_TOKEN_USER=\"" closed "\""
            }
            if ($0 ~ /SCM_TOKEN_TOKEN=/) {
                prefix = ($0 ~ /^#/) ? "# " : ""
                $0 = prefix "export SCM_TOKEN_TOKEN=\"" closed "\""
            }
            if ($0 ~ /OIDC_CLIENT_ID=/) {
                prefix = ($0 ~ /^#/) ? "# " : ""
                $0 = prefix "export OIDC_CLIENT_ID=\"" closed "\""
            }
            if ($0 ~ /OIDC_CLIENT_SECRET=/) {
                prefix = ($0 ~ /^#/) ? "# " : ""
                $0 = prefix "export OIDC_CLIENT_SECRET=\"" closed "\""
            }
            if ($0 ~ /OIDC_USER=/) {
                prefix = ($0 ~ /^#/) ? "# " : ""
                $0 = prefix "export OIDC_USER=\"" closed "\""
            }
            print
        }' "$target_dir/envrc" > "$target_dir/envrc.tmp" && mv "$target_dir/envrc.tmp" "$target_dir/envrc"
    fi

    # Note: We NO LONGER delete configs/${name}-context.yaml here.
    # The configuration YAML should persist locally so the user can 
    # view or edit non-sensitive values (like node IPs) while the context is dehydrated.
}

function ensure_gsa_key() {
    local target_file="$1"
    local secret_name="$2"
    local cl_name="$3"
    local p_id="$4"
    local sa_description="$5"
    local reg="$6"

    # Try to fetch from GSM first
    local key_content=$(gsm_get "$secret_name" "$p_id" "$reg")

    if [[ -n "$key_content" ]]; then
        echo "$key_content" > "$target_file"
        return 0
    fi

    # Not in GSM, check local filesystem
    if [[ -f "$target_file" ]]; then
        # If local but missing in GSM, push it
        gsm_put "$secret_name" "$(cat "$target_file")" "$cl_name" "$p_id" "$reg"
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
                gsm_put "$secret_name" "$(cat "$target_file")" "$cl_name" "$p_id" "$reg"
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
    local reg=$(grep "export REGION=" "$target_dir/envrc" | cut -d'"' -f2)

    if [[ -z "$cl_name" ]]; then
        pretty_print "Error: Could not find CLUSTER_ACM_NAME in $target_dir/envrc" "ERROR"
        return
    fi
    if [[ -z "$p_id" ]]; then
        pretty_print "Error: Could not find PROJECT_ID in $target_dir/envrc" "ERROR"
        return
    fi

    local ctx_name=$(get_active_folder)

    pretty_print "Opening context for cluster $cl_name in project $p_id..." "INFO"

    # 1. SSH Keys
    local ssh_key=$(get_secret "ssh_key" "gdc-${cl_name}-ssh-key" "true" "$p_id" "$reg" "$ctx_name")
    if [[ -n "$ssh_key" ]]; then
        echo "$ssh_key" > "$target_dir/consumer-edge-machine"
        trim_key_file "$target_dir/consumer-edge-machine"
        chmod 400 "$target_dir/consumer-edge-machine"
    fi

    local ssh_pub_key=$(get_secret "ssh_pub_key" "gdc-${cl_name}-ssh-key-pub" "true" "$p_id" "$reg" "$ctx_name")
    if [[ -n "$ssh_pub_key" ]]; then
        echo "$ssh_pub_key" > "$target_dir/consumer-edge-machine.pub"
        trim_key_file "$target_dir/consumer-edge-machine.pub"
        chmod 644 "$target_dir/consumer-edge-machine.pub"
    fi

    # 2. GSA Keys
    local prov_gsa=$(get_secret "prov_gsa" "gdc-${cl_name}-prov-gsa" "true" "$p_id" "$reg" "$ctx_name")
    if [[ -n "$prov_gsa" ]]; then
        echo "$prov_gsa" > "$target_dir/provisioning-gsa.json"
    fi

    local node_gsa=$(get_secret "node_gsa" "gdc-${cl_name}-node-gsa" "true" "$p_id" "$reg" "$ctx_name")
    if [[ -n "$node_gsa" ]]; then
        echo "$node_gsa" > "$target_dir/node-gsa.json"
    fi

    # 3. SCM & OIDC Secrets
    local scm_user=$(get_secret "scm_user" "gdc-${cl_name}-scm-user" "true" "$p_id" "$reg" "$ctx_name")
    local scm_token=$(get_secret "scm_token" "gdc-${cl_name}-scm-token" "true" "$p_id" "$reg" "$ctx_name")
    local oidc_id=$(get_secret "oidc_id" "gdc-${cl_name}-oidc-id" "false" "$p_id" "$reg" "$ctx_name")
    local oidc_secret=$(get_secret "oidc_secret" "gdc-${cl_name}-oidc-secret" "false" "$p_id" "$reg" "$ctx_name")
    local oidc_user=$(get_secret "oidc_user" "gdc-${cl_name}-oidc-user" "false" "$p_id" "$reg" "$ctx_name")

    # Inject into envrc (always run awk now to handle commenting out)
    awk -v scm_u="$scm_user" -v scm_t="$scm_token" -v oidc_i="$oidc_id" -v oidc_s="$oidc_secret" -v oidc_u="$oidc_user" '{
        if ($0 ~ /SCM_TOKEN_USER=/) {
            if (scm_u != "") $0 = "export SCM_TOKEN_USER=\""scm_u"\""
            else if ($0 ~ /^export/) $0 = "export SCM_TOKEN_USER=\"\""
        }
        if ($0 ~ /SCM_TOKEN_TOKEN=/) {
            if (scm_t != "") $0 = "export SCM_TOKEN_TOKEN=\""scm_t"\""
            else if ($0 ~ /^export/) $0 = "export SCM_TOKEN_TOKEN=\"\""
        }
        if ($0 ~ /OIDC_CLIENT_ID=/) {
            if (oidc_i != "") $0 = "export OIDC_CLIENT_ID=\""oidc_i"\""
            else $0 = "# export OIDC_CLIENT_ID=\"\""
        }
        if ($0 ~ /OIDC_CLIENT_SECRET=/) {
            if (oidc_s != "") $0 = "export OIDC_CLIENT_SECRET=\""oidc_s"\""
            else $0 = "# export OIDC_CLIENT_SECRET=\"\""
        }
        if ($0 ~ /OIDC_USER=/) {
            if (oidc_u != "") $0 = "export OIDC_USER=\""oidc_u"\""
            else $0 = "# export OIDC_USER=\"\""
        }
        if ($0 ~ /OIDC_ENABLED=/) {
            if (oidc_i != "" && oidc_s != "") $0 = "export OIDC_ENABLED=\"true\""
            else $0 = "export OIDC_ENABLED=\"false\""
        }
        print
    }' "$target_dir/envrc" > "$target_dir/envrc.tmp" && mv "$target_dir/envrc.tmp" "$target_dir/envrc"

    # 4. Config Restoration
    local config_yaml=$(get_secret "config_yaml" "gdc-${cl_name}-config-yaml" "false" "$p_id" "$reg" "$ctx_name")
    if [[ -n "$config_yaml" ]]; then
        mkdir -p configs
        local target_yaml="configs/${ctx_name}-context.yaml"
        if [[ -f "$target_yaml" ]]; then
            # Check if contents differ
            local current_yaml=$(cat "$target_yaml")
            if [[ "$current_yaml" != "$config_yaml" ]]; then
                pretty_print "Warning: $target_yaml already exists and differs from GSM." "WARN"
                echo -n "Would you like to overwrite it with the version from GSM? (y/n): "
                read answer
                if [[ "$answer" == "y" ]]; then
                    echo "$config_yaml" > "$target_yaml"
                    pretty_print "Overwrote $target_yaml with GSM version" "INFO"
                else
                    pretty_print "Skipped restoring $target_yaml (kept local version)" "INFO"
                fi
            else
                pretty_print "Verified $target_yaml matches GSM version" "INFO"
            fi
        else
            echo "$config_yaml" > "$target_yaml"
            pretty_print "Restored $target_yaml from GSM" "INFO"
        fi
    fi

    pretty_print "Context hydrated successfully." "INFO"

    # Summary
    pretty_print "Summary" "INFO"
    pretty_print "======================================="
    pretty_print "GCP Project ID:\t\t$p_id"
    pretty_print "SCM User Secret:\t${scm_user:-NOT SET}"
    pretty_print "SCM Token Secret:\t$(mask_secret "$scm_token")"
    pretty_print "Provisioning GSA:\t$(echo "$prov_gsa" | jq -r '.client_email' 2>/dev/null || echo "NOT SET")"
    pretty_print "Node GSA:\t\t$(echo "$node_gsa" | jq -r '.client_email' 2>/dev/null || echo "NOT SET")"
    echo ""
    pretty_print "Context $cl_name State: [opened]" "INFO"
    pretty_print "======================================="
    pretty_print "This context is now hydrated and ready for use."
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
    local reg=$(grep "export REGION=" "$target_dir/envrc" | cut -d'"' -f2)

    if [[ -z "$cl_name" || -z "$p_id" ]]; then
        pretty_print "Error: CLUSTER_ACM_NAME and PROJECT_ID must be set in envrc for ingestion." "ERROR"
        exit 1
    fi

    if gcloud secrets describe "context-${name}" --project="${p_id}" &>/dev/null; then
        pretty_print "There is an existing cloud-based config, run with -d to download the context." "ERROR"
        exit 1
    fi

    pretty_print "Ingesting $name into project $p_id (cluster: $cl_name)..." "INFO"

    # 1. Ingest Files
    if [[ -f "$target_dir/consumer-edge-machine" ]]; then
        gsm_put "gdc-${cl_name}-ssh-key" "$(cat "$target_dir/consumer-edge-machine")" "$cl_name" "$p_id" "$reg"
    fi
    if [[ -f "$target_dir/consumer-edge-machine.pub" ]]; then
        gsm_put "gdc-${cl_name}-ssh-key-pub" "$(cat "$target_dir/consumer-edge-machine.pub")" "$cl_name" "$p_id" "$reg"
    fi
    if [[ -f "$target_dir/provisioning-gsa.json" ]]; then
        gsm_put "gdc-${cl_name}-prov-gsa" "$(cat "$target_dir/provisioning-gsa.json")" "$cl_name" "$p_id" "$reg"
    fi
    if [[ -f "$target_dir/node-gsa.json" ]]; then
        gsm_put "gdc-${cl_name}-node-gsa" "$(cat "$target_dir/node-gsa.json")" "$cl_name" "$p_id" "$reg"
    fi

    # 2. Ingest Vars
    local scm_user=$(grep "^export SCM_TOKEN_USER=" "$target_dir/envrc" | cut -d'"' -f2)
    local scm_token=$(grep "^export SCM_TOKEN_TOKEN=" "$target_dir/envrc" | cut -d'"' -f2)
    local oidc_id=$(grep "^export OIDC_CLIENT_ID=" "$target_dir/envrc" | cut -d'"' -f2)
    local oidc_secret=$(grep "^export OIDC_CLIENT_SECRET=" "$target_dir/envrc" | cut -d'"' -f2)
    local oidc_user=$(grep "^export OIDC_USER=" "$target_dir/envrc" | cut -d'"' -f2)

    if [[ -n "$scm_user" && "$scm_user" != "****closed*******" ]]; then gsm_put "gdc-${cl_name}-scm-user" "$scm_user" "$cl_name" "$p_id" "$reg"; fi
    if [[ -n "$scm_token" && "$scm_token" != "****closed*******" ]]; then gsm_put "gdc-${cl_name}-scm-token" "$scm_token" "$cl_name" "$p_id" "$reg"; fi
    if [[ -n "$oidc_id" && "$oidc_id" != "****closed*******" ]]; then gsm_put "gdc-${cl_name}-oidc-id" "$oidc_id" "$cl_name" "$p_id" "$reg"; fi
    if [[ -n "$oidc_secret" && "$oidc_secret" != "****closed*******" ]]; then gsm_put "gdc-${cl_name}-oidc-secret" "$oidc_secret" "$cl_name" "$p_id" "$reg"; fi
    if [[ -n "$oidc_user" && "$oidc_user" != "****closed*******" ]]; then gsm_put "gdc-${cl_name}-oidc-user" "$oidc_user" "$cl_name" "$p_id" "$reg"; fi

    # 3. Generate YAML Backup from Template
    pretty_print "Generating YAML backup in configs/${name}-context.yaml..." "INFO"
    mkdir -p configs
    local yaml_out="configs/${name}-context.yaml"

    # Start with the template
    cp templates/context-config-template.yaml "$yaml_out"

    local zn=$(grep "^export ZONE=" "$target_dir/envrc" | cut -d'"' -f2)
    local repo_url=$(grep "^export ROOT_REPO_URL=" "$target_dir/envrc" | cut -d'"' -f2)
    local repo_branch=$(grep "^export ROOT_REPO_BRANCH=" "$target_dir/envrc" | cut -d'"' -f2)

    local inv_cl_name=$(echo "$cl_name" | tr '-' '_')
    local cp_vip=$(yq e ".[\"${inv_cl_name}_cluster\"].vars.control_plane_vip" "$target_dir/inventory.yaml" 2>/dev/null)
    local in_vip=$(yq e ".[\"${inv_cl_name}_cluster\"].vars.ingress_vip" "$target_dir/inventory.yaml" 2>/dev/null)
    local lb_pool=$(yq e ".[\"${inv_cl_name}_cluster\"].vars.load_balancer_pool_cidr[0]" "$target_dir/inventory.yaml" 2>/dev/null)

    local abm_ver=$(yq e '.abm_version' "$target_dir/instance-run-vars.yaml" 2>/dev/null)
    local acm_ver=$(yq e '.acm_version' "$target_dir/instance-run-vars.yaml" 2>/dev/null)
    local storage=$(yq e '.storage_provider' "$target_dir/instance-run-vars.yaml" 2>/dev/null)

    # Update core values using yq safely
    name="$name" yq e -i '.context_name = env(name)' "$yaml_out"
    cl_name="$cl_name" yq e -i '.cluster_name = env(cl_name)' "$yaml_out"
    p_id="$p_id" yq e -i '.project_id = env(p_id)' "$yaml_out"

    if [[ -n "$reg" ]]; then reg="$reg" yq e -i '.region = env(reg)' "$yaml_out"; fi
    if [[ -n "$zn" ]]; then zn="$zn" yq e -i '.zone = env(zn)' "$yaml_out"; fi

    if [[ -n "$cp_vip" && "$cp_vip" != "null" ]]; then cp_vip="$cp_vip" yq e -i '.control_plane_vip = env(cp_vip)' "$yaml_out"; fi
    if [[ -n "$in_vip" && "$in_vip" != "null" ]]; then in_vip="$in_vip" yq e -i '.ingress_vip = env(in_vip)' "$yaml_out"; fi
    if [[ -n "$lb_pool" && "$lb_pool" != "null" ]]; then lb_pool="$lb_pool" yq e -i '.load_balancer_pool_cidr = env(lb_pool)' "$yaml_out"; fi

    if [[ -n "$repo_url" && "$repo_url" != "null" ]]; then repo_url="$repo_url" yq e -i '.root_repo_url = env(repo_url)' "$yaml_out"; fi
    if [[ -n "$repo_branch" && "$repo_branch" != "null" ]]; then repo_branch="$repo_branch" yq e -i '.root_repo_branch = env(repo_branch)' "$yaml_out"; fi

    if [[ -n "$storage" && "$storage" != "null" ]]; then storage="$storage" yq e -i '.storage_provider = env(storage)' "$yaml_out"; fi
    if [[ -n "$abm_ver" && "$abm_ver" != "null" ]]; then abm_ver="$abm_ver" yq e -i '.abm_version = env(abm_ver)' "$yaml_out"; fi
    if [[ -n "$acm_ver" && "$acm_ver" != "null" ]]; then acm_ver="$acm_ver" yq e -i '.acm_version = env(acm_ver)' "$yaml_out"; fi

    # Handle Robin disk paths (if Robin is the storage provider)
    if [[ "$storage" == "robin" ]]; then
        local num_disks=$(yq e '.robin_disk_paths | length' "$target_dir/instance-run-vars.yaml" 2>/dev/null)
        if [[ "$num_disks" -gt 0 && "$num_disks" != "null" ]]; then
            # Empty the default array in the template
            yq e -i '.robin_disk_paths = []' "$yaml_out"
            for (( i=0; i<$num_disks; i++ )); do
                local disk_path=$(yq e ".robin_disk_paths[$i]" "$target_dir/instance-run-vars.yaml")
                yq e -i ".robin_disk_paths += [\"${disk_path}\"]" "$yaml_out"
            done
        fi

        local robin_bundle=$(yq e '.robin_install_bundle_file' "$target_dir/instance-run-vars.yaml" 2>/dev/null)
        if [[ -n "$robin_bundle" && "$robin_bundle" != "null" ]]; then
             robin_bundle="$robin_bundle" yq e -i '.robin_install_bundle_file = env(robin_bundle)' "$yaml_out"
        fi
    fi

    # Handle Nodes Array
    local num_nodes=$(yq e ".[\"${inv_cl_name}_cluster\"].hosts | length" "$target_dir/inventory.yaml" 2>/dev/null)
    if [[ "$num_nodes" -gt 0 && "$num_nodes" != "null" ]]; then
        # Clear the dummy nodes from the template safely using yq
        yq e -i '.nodes = []' "$yaml_out"
        local node_names=$(yq e ".[\"${inv_cl_name}_cluster\"].hosts | keys | .[]" "$target_dir/inventory.yaml" 2>/dev/null)
        for n_name in $node_names; do
            local n_ip=$(yq e ".[\"${inv_cl_name}_cluster\"].hosts.\"${n_name}\".node_ip" "$target_dir/inventory.yaml" 2>/dev/null)
            # Append object to nodes array
            yq e -i ".nodes += [{\"name\": \"${n_name}\", \"ip\": \"${n_ip}\"}]" "$yaml_out"
        done
    fi

    # Push YAML to GSM
    gsm_put "context-${name}" "$(cat "$yaml_out")" "$cl_name" "$p_id" "$reg"

    # 4. Secure the folder
    dehydrate_context "$target_dir"

    pretty_print "Ingestion complete for $name." "INFO"

    # Summary
    pretty_print "Summary" "INFO"
    pretty_print "======================================="
    pretty_print "GCP Project ID:\t\t$p_id"
    pretty_print "SCM User Secret:\t${scm_user:-NOT SET}"
    pretty_print "SCM Token Secret:\t$(mask_secret "$scm_token")"
    pretty_print "Provisioning GSA:\t$(get_gsa_email_from_secret "gdc-${cl_name}-prov-gsa" "$p_id" "$reg")"
    pretty_print "Node GSA:\t\t$(get_gsa_email_from_secret "gdc-${cl_name}-node-gsa" "$p_id" "$reg")"
    echo ""
    pretty_print "Context $name State: [closed]" "INFO"
    pretty_print "======================================="
    pretty_print "To activate and open this context for use:"
    pretty_print "  ./scripts/instance-context.sh -o $name"
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
    local reg="$3"
    local content=$(gsm_get "$secret_name" "$p_id" "$reg")
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

function validate_gsm_secret() {
    local secret_name="$1"
    local p_id="$2"
    local missing_action="${3:-MISSING}"
    local reg="$4"

    if { gcloud secrets describe "${secret_name}" --project="${p_id}" &>/dev/null || gcloud secrets describe "${secret_name}" --project="${p_id}" --location="${reg}" &>/dev/null; }; then
        echo "OK"
    else
        echo "$missing_action"
    fi
}

function generate_context() {
    local yaml_file="$1"

    if ! command -v yq &> /dev/null; then
        pretty_print "Error: 'yq' is required. Please install it." "ERROR"
        exit 1
    fi
    
    local yq_version=$(yq --version 2>&1)
    if echo "$yq_version" | grep -qv "mikefarah"; then
        pretty_print "Error: This script requires mikefarah/yq (v4+). Detected a different 'yq' (likely kislyuk/yq)." "ERROR"
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
    local root_repo_url=$(yq e '.root_repo_url // "https://gitlab.com/gcp-solutions-public/retail-edge/primary-root-repo-template.git"' "$yaml_file")
    local root_repo_branch=$(yq e '.root_repo_branch // "main"' "$yaml_file")
    local storage_provider=$(yq e '.storage_provider // ""' "$yaml_file")
    local abm_version=$(yq e '.abm_version // ""' "$yaml_file")
    local acm_version=$(yq e '.acm_version // ""' "$yaml_file")
    local robin_bundle=$(yq e '.robin_install_bundle_file // ""' "$yaml_file")

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
    pretty_print "Google Project ID:\t[$p_id]"
    pretty_print "YAML Config File:\t[$yaml_file]"

    local scm_user_status=$(validate_gsm_secret "gdc-${cl_name}-scm-user" "$p_id" "MISSING" "$reg")
    local scm_token_status=$(validate_gsm_secret "gdc-${cl_name}-scm-token" "$p_id" "MISSING" "$reg")

    local prov_missing_action="WILL_PROMPT"
    local node_missing_action="WILL_PROMPT"
    if [[ -f "$target/provisioning-gsa.json" ]]; then prov_missing_action="WILL_UPLOAD_LOCAL"; fi
    if [[ -f "$target/node-gsa.json" ]]; then node_missing_action="WILL_UPLOAD_LOCAL"; fi

    local prov_gsa_status=$(validate_gsm_secret "gdc-${cl_name}-prov-gsa" "$p_id" "$prov_missing_action" "$reg")
    local node_gsa_status=$(validate_gsm_secret "gdc-${cl_name}-node-gsa" "$p_id" "$node_missing_action" "$reg")

    local ssh_key_status=$(validate_gsm_secret "gdc-${cl_name}-ssh-key" "$p_id" "WILL_GENERATE" "$reg")
    local ssh_pub_status=$(validate_gsm_secret "gdc-${cl_name}-ssh-key-pub" "$p_id" "WILL_GENERATE" "$reg")

    local oidc_id_status=$(validate_gsm_secret "gdc-${cl_name}-oidc-id" "$p_id" "OPTIONAL" "$reg")
    local oidc_sec_status=$(validate_gsm_secret "gdc-${cl_name}-oidc-secret" "$p_id" "OPTIONAL" "$reg")

    pretty_print "SCM User Secret:\t[$scm_user_status]"
    pretty_print "SCM Token Secret:\t[$scm_token_status]"
    pretty_print "Prov GSA Secret:\t[$prov_gsa_status]"
    pretty_print "Node GSA Secret:\t[$node_gsa_status]"
    pretty_print "SSH Private Key:\t[$ssh_key_status]"
    pretty_print "SSH Public Key:\t\t[$ssh_pub_status]"
    pretty_print "OIDC Client ID (Opt):\t[$oidc_id_status]"
    pretty_print "OIDC Secret (Opt):\t[$oidc_sec_status]"
    echo ""

    if [[ "$scm_user_status" == "MISSING" || "$scm_token_status" == "MISSING" ]]; then
        if [[ "$GSM_SKIP_VALIDATION" == "true" ]]; then
            pretty_print "WARN: Required SCM secrets missing in GSM, but GSM_SKIP_VALIDATION is true. Bypassing check." "WARN"
        else
            pretty_print "STOP: Required SCM secrets missing in GSM. Please create them first." "ERROR"
            exit 1
        fi
    fi

    # 2. Display Settings
    pretty_print "2. Display Settings" "INFO"
    pretty_print "======================================="

    local scm_user_val=$(gsm_get "gdc-${cl_name}-scm-user" "$p_id" "$reg")
    local scm_token_val=$(gsm_get "gdc-${cl_name}-scm-token" "$p_id" "$reg")
    local prov_gsa_email=$(get_gsa_email_from_secret "gdc-${cl_name}-prov-gsa" "$p_id" "$reg")
    local node_gsa_email=$(get_gsa_email_from_secret "gdc-${cl_name}-node-gsa" "$p_id" "$reg")
    local oidc_id_val=$(gsm_get "gdc-${cl_name}-oidc-id" "$p_id" "$reg")
    local oidc_sec_val=$(gsm_get "gdc-${cl_name}-oidc-secret" "$p_id" "$reg")

    pretty_print "SCM User Secret:\t${scm_user_val:-NOT SET}"
    pretty_print "SCM Token Secret:\t$(mask_secret "$scm_token_val")"
    pretty_print "Provisioning GSA:\t$prov_gsa_email"
    pretty_print "Node GSA:\t\t$node_gsa_email"
    pretty_print "OIDC Client ID (Opt):\t${oidc_id_val:-NOT SET}"
    pretty_print "OIDC Secret (Opt):\t$(mask_secret "$oidc_sec_val")"
    pretty_print "Cluster Name:\t\t$cl_name"
    pretty_print "Region/Zone:\t\t$reg / $zn"
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
        mkdir -p "$target"
        cp "build-artifacts-example/add-hosts-example" "$target/add-hosts" 2>/dev/null || touch "$target/add-hosts"
        cp "build-artifacts-example/ssh-config" "$target/ssh-config" 2>/dev/null || touch "$target/ssh-config"
    fi

    # 1. Update envrc
    if [[ ! -f "$target/envrc" ]]; then
        cp templates/envrc-template.sh "$target/envrc"
    fi

    awk -v p_id="$p_id" -v reg="$reg" -v zn="$zn" -v cl_name="$cl_name" -v r_url="$root_repo_url" -v r_branch="$root_repo_branch" '
    BEGIN { print "# This file sets environment variables for the cluster provisioning run." }
    {
        gsub(/export PROJECT_ID=.*/, "export PROJECT_ID=\""p_id"\" # GCP Project ID (from YAML project_id)")
        gsub(/export REGION=.*/, "export REGION=\""reg"\" # GCP Region (from YAML region)")
        gsub(/export ZONE=.*/, "export ZONE=\""zn"\" # GCP Zone (from YAML zone)")
        gsub(/export CLUSTER_ACM_NAME=.*/, "export CLUSTER_ACM_NAME=\""cl_name"\" # Cluster name used by ACM (from YAML cluster_name)")
        
        if ($0 ~ /export ROOT_REPO_URL=/) {
            print "export ROOT_REPO_URL=\""r_url"\" # Root SCM Repo"
            if (!branch_added) {
                print "export ROOT_REPO_BRANCH=\""r_branch"\""
                branch_added = 1
            }
            next
        }
        
        if ($0 ~ /export ROOT_REPO_BRANCH=/) {
            if (!branch_added) {
                print "export ROOT_REPO_BRANCH=\""r_branch"\""
                branch_added = 1
            }
            next
        }
        
        print
    }
    ' "$target/envrc" > "$target/envrc.tmp" && mv "$target/envrc.tmp" "$target/envrc"

    # 2. Update inventory.yaml
    if [[ ! -f "$target/inventory.yaml" ]]; then
        cp templates/inventory-physical-example.yaml "$target/inventory.yaml"
    fi

    # Rename root key and update basic vars
    yq e -i ".[\"${cl_name}_cluster\"] = .[\"[[ cluster-name]]_cluster\"]" "$target/inventory.yaml"
    yq e -i "del(.[\"[[ cluster-name]]_cluster\"])" "$target/inventory.yaml"
    yq e -i ".[\"${cl_name}_cluster\"].vars.cluster_name = \"${cl_name}\"" "$target/inventory.yaml"
    yq e -i ".[\"${cl_name}_cluster\"].vars.acm_cluster_name = \"${cl_name}\"" "$target/inventory.yaml"
    yq e -i ".[\"${cl_name}_cluster\"].vars.control_plane_vip = \"${cp_vip}\"" "$target/inventory.yaml"
    yq e -i ".[\"${cl_name}_cluster\"].vars.ingress_vip = \"${in_vip}\"" "$target/inventory.yaml"
    yq e -i ".[\"${cl_name}_cluster\"].vars.load_balancer_pool_cidr = [\"${lb_pool}\"]" "$target/inventory.yaml"
    yq e -i "del(.[\"${cl_name}_cluster\"].hosts)" "$target/inventory.yaml"
    yq e -i ".[\"${cl_name}_cluster\"].hosts = {}" "$target/inventory.yaml"
    yq e -i "del(.[\"${cl_name}_cluster\"].vars.peer_node_ips)" "$target/inventory.yaml"
    yq e -i ".[\"${cl_name}_cluster\"].vars.peer_node_ips = []" "$target/inventory.yaml"

    # Parse nodes for inventory hosts
    local num_nodes=$(yq e '.nodes | length' "$yaml_file")

    echo "# Edge Servers for ${ctx_name} (Auto-generated from YAML nodes)" > "$target/add-hosts"
    echo "# Used for local DNS resolution to cluster nodes." >> "$target/add-hosts"

    for (( i=0; i<$num_nodes; i++ )); do
        local n_name=$(yq e ".nodes[$i].name" "$yaml_file")
        local n_ip=$(yq e ".nodes[$i].ip" "$yaml_file")

        # Add to inventory hosts
        yq e -i ".[\"${cl_name}_cluster\"].hosts.\"${n_name}\".node_ip = \"${n_ip}\"" "$target/inventory.yaml"
        yq e -i ".[\"${cl_name}_cluster\"].hosts.\"${n_name}\".machine_label = \"{{ inventory_hostname }}\"" "$target/inventory.yaml"
        yq e -i ".[\"${cl_name}_cluster\"].hosts.\"${n_name}\".ansible_host = \"{{ node_ip }}\"" "$target/inventory.yaml"

        if [ $i -eq 0 ]; then
            yq e -i ".[\"${cl_name}_cluster\"].hosts.\"${n_name}\".primary_cluster_machine = true" "$target/inventory.yaml"
        fi

        # Add to peer_node_ips list
        yq e -i ".[\"${cl_name}_cluster\"].vars.peer_node_ips += [\"${n_ip}\"]" "$target/inventory.yaml"

        # Add to add-hosts
        echo "$n_ip    $n_name" >> "$target/add-hosts"
    done

    # 3. Update instance-run-vars.yaml
    if [[ ! -f "$target/instance-run-vars.yaml" ]]; then
        cp templates/instance-run-vars-template.yaml "$target/instance-run-vars.yaml"
    fi
    
    if [[ -n "$storage_provider" && "$storage_provider" != "null" ]]; then
        storage_provider="$storage_provider" yq e -i '.storage_provider = env(storage_provider)' "$target/instance-run-vars.yaml"

        if [[ "$storage_provider" == "robin" ]]; then
            local num_disks=$(yq e '.robin_disk_paths | length' "$yaml_file")
            if [[ "$num_disks" -gt 0 && "$num_disks" != "null" ]]; then
                yq e -i '.robin_disk_paths = []' "$target/instance-run-vars.yaml"
                for (( i=0; i<$num_disks; i++ )); do
                    local disk_path=$(yq e ".robin_disk_paths[$i]" "$yaml_file")
                    disk_path="$disk_path" yq e -i '.robin_disk_paths += [env(disk_path)]' "$target/instance-run-vars.yaml"
                done
            fi
        fi
    fi

    if [[ -n "$abm_version" && "$abm_version" != "null" ]]; then
        abm_version="$abm_version" yq e -i '.abm_version = env(abm_version)' "$target/instance-run-vars.yaml"
    fi

    if [[ -n "$acm_version" && "$acm_version" != "null" ]]; then
        acm_version="$acm_version" yq e -i '.acm_version = env(acm_version)' "$target/instance-run-vars.yaml"
    fi

    if [[ "$storage_provider" == "robin" && -n "$robin_bundle" && "$robin_bundle" != "null" ]]; then
        robin_bundle="$robin_bundle" yq e -i '.robin_install_bundle_file = env(robin_bundle)' "$target/instance-run-vars.yaml"
    fi

    # 4. Handle SSH Keys
    local existing_ssh=$(gsm_get "gdc-${cl_name}-ssh-key" "$p_id" "$reg")
    if [[ -n "$existing_ssh" ]]; then
        pretty_print "Existing SSH key found in GSM, using it." "INFO"
        echo "$existing_ssh" > "$target/consumer-edge-machine"
        trim_key_file "$target/consumer-edge-machine"
        chmod 400 "$target/consumer-edge-machine"
        gsm_get "gdc-${cl_name}-ssh-key-pub" "$p_id" "$reg" > "$target/consumer-edge-machine.pub"
        trim_key_file "$target/consumer-edge-machine.pub"
        chmod 644 "$target/consumer-edge-machine.pub"
    else
        pretty_print "No SSH key found in GSM, generating new pair..." "INFO"
        rm -f "$target/consumer-edge-machine" "$target/consumer-edge-machine.pub"
        ssh-keygen -t rsa -b 4096 -f "$target/consumer-edge-machine" -N "" -q
        trim_key_file "$target/consumer-edge-machine"
        trim_key_file "$target/consumer-edge-machine.pub"
    fi

    # 5. Ensure GSA keys are handled (prompt if missing)
    ensure_gsa_key "$target/provisioning-gsa.json" "gdc-${cl_name}-prov-gsa" "$cl_name" "$p_id" "Provisioning GSA" "$reg"
    ensure_gsa_key "$target/node-gsa.json" "gdc-${cl_name}-node-gsa" "$cl_name" "$p_id" "Node GSA" "$reg"

    # 6. Push to GSM
    if [[ -z "$existing_ssh" ]]; then
        gsm_put "gdc-${cl_name}-ssh-key" "$(cat "$target/consumer-edge-machine")" "${cl_name}" "${p_id}" "$reg"
        gsm_put "gdc-${cl_name}-ssh-key-pub" "$(cat "$target/consumer-edge-machine.pub")" "${cl_name}" "${p_id}" "$reg"
    fi

    # Push YAML to GSM (as context name backup)
    gsm_put "context-${ctx_name}" "$(cat "$yaml_file")" "${cl_name}" "${p_id}" "$reg"

    # Save a copy in configs/ if it's not already there
    mkdir -p configs
    if [[ ! "$yaml_file" -ef "configs/${ctx_name}-context.yaml" ]]; then
        cp "$yaml_file" "configs/${ctx_name}-context.yaml"
    fi

    dehydrate_context "$target"

    pretty_print "Context $ctx_name generated successfully and closed (dehydrated)." "SUCCESS"
}

function create_context() {
    local name="$1"
    if [[ -z "$name" ]]; then
        pretty_print "Error: Context name required for create." "ERROR"
        exit 1
    fi

    local target="build-artifacts-${name}"
    local config_yaml="configs/${name}-context.yaml"

    local project_id=$(gcloud config get-value project 2>/dev/null)
    if [[ -n "$project_id" ]]; then
        if gcloud secrets describe "context-${name}" --project="${project_id}" &>/dev/null; then
            pretty_print "There is an existing cloud-based config, run with -d to download the context." "ERROR"
            exit 1
        fi
    fi

    # 1. Validation
    if [[ -d "$target" ]]; then
        pretty_print "Error: Context '${name}' already exists at ${target}." "ERROR"
        exit 1
    fi

    pretty_print "Creating new context: ${name}" "INFO"

    # 2. Scaffolding
    mkdir -p "$target"
    mkdir -p configs

    # Copy template files
    cp "build-artifacts-example/add-hosts-example" "$target/add-hosts"
    cp "build-artifacts-example/ssh-config" "$target/ssh-config"
    cp "templates/envrc-template.sh" "$target/envrc"
    cp "templates/instance-run-vars-template.yaml" "$target/instance-run-vars.yaml"
    cp "templates/inventory-physical-example.yaml" "$target/inventory.yaml"
    cp "templates/context-config-template.yaml" "$config_yaml"

    # 3. YAML Update
    if command -v yq &> /dev/null; then
        name="$name" yq e -i '.context_name = env(name)' "$config_yaml"
    else
        pretty_print "Warning: 'yq' not found. Skipping auto-update of context_name in ${config_yaml}." "WARN"
    fi

    # 4. GSM Sync
    echo -n "Would you like to sync this config to GSM? (y/n): "
    read answer
    if [[ "$answer" == "y" ]]; then
        # Use gsm_put if available, but we need project_id.
        # Since it's a new context, we might not have project_id yet.
        # We can try to extract it from the template or prompt.
        local p_id=$(yq e '.project_id' "$config_yaml" 2>/dev/null)
        if [[ "$p_id" == "null" || -z "$p_id" ]]; then
             pretty_print "Enter the GCP Project ID for GSM sync: " "INPUT"
             read p_id
        fi

        if [[ -n "$p_id" ]]; then
            gsm_put "context-${name}" "$(cat "$config_yaml")" "" "$p_id" ""
            pretty_print "Config synced to GSM as 'context-${name}'" "SUCCESS"
        else
            pretty_print "Skipping GSM sync: No Project ID provided." "WARN"
        fi
    fi

    # 5. Final UX: Link as active
    rm -f build-artifacts
    ln -s "$target" build-artifacts
    pretty_print "Context '${name}' created and linked as active." "SUCCESS"
    pretty_print "Location: ${target}"
    pretty_print "Config: ${config_yaml}"
    pretty_print "\nPlease edit ${config_yaml} or the files in ${target} to match your environment." "INFO"
}

function download_context() {
    local name="$1"
    if [[ -z "$name" ]]; then
        pretty_print "Error: Context name required for download." "ERROR"
        exit 1
    fi

    local project_id=$(gcloud config get-value project 2>/dev/null)
    if [[ -z "$project_id" ]]; then
        pretty_print "Error: Could not retrieve GCP project ID. Ensure gcloud is configured." "ERROR"
        exit 1
    fi

    local secret_name="context-${name}"
    pretty_print "Downloading context configuration '${name}' from project '${project_id}'..." "INFO"

    # Capture output and exit code
    local content
    content=$(gcloud secrets versions access latest --secret="${secret_name}" --project="${project_id}" 2>&1)
    local status=$?

    if [[ $status -ne 0 ]]; then
        pretty_print "Context configuration not found in Google Secret Manager with ${name} and ${project_id}" "ERROR"
        pretty_print "Underlying error: ${content}" "DEBUG"
        exit 1
    fi

    mkdir -p configs || { pretty_print "Error: Failed to create configs directory." "ERROR"; exit 1; }
    local target_yaml="configs/${name}-context.yaml"
    
    if ! echo "$content" > "$target_yaml"; then
        pretty_print "Error: Failed to write context configuration to ${target_yaml}." "ERROR"
        exit 1
    fi

    pretty_print "Successfully downloaded context configuration to ${target_yaml}" "SUCCESS"
}

function switch_context() {
    local name="$1"
    if [[ -z "$name" ]]; then
        display_folders $(get_active_folder)
        return
    fi

    local active=$(get_active_folder)
    if [[ "$name" == "$active" ]]; then
        pretty_print "Current context is already ${active}, no action will be taken" "DEBUG"
        print_context
        return
    fi

    local available_folders=$(get_list_of_folders)
    local found=false
    for f in $available_folders; do
        if [[ "$f" == "$name" ]]; then
            found=true
            break
        fi
    done

    if [[ "$found" == false ]]; then
        pretty_print "The desired context '${name}' does not exist, would you like to create it? (y/n)"
        read answer
        if [[ "$answer" == "y" ]]; then
            create_context "$name"
        else
            pretty_print "No action taken" "ERROR"
            exit 0
        fi
    else
        pretty_print "Setting Context to '${name}'" "INFO"
        rm -rf build-artifacts
        ln -s "build-artifacts-${name}" build-artifacts
        if [[ -x "$(command -v direnv)" ]]; then
            direnv allow .
        else
            pretty_print "direnv not installed, perhaps you should 'source .envrc'"
        fi
        pretty_print "Don't forget to check your gcloud current config"
    fi
}

#### Main Execution

case "$ACTION" in
    CREATE) create_context "$CONTEXT_NAME" ;;
    DOWNLOAD) download_context "$CONTEXT_NAME" ;;
    GENERATE) generate_context "$YAML_FILE" ;;
    OPEN) hydrate_context "build-artifacts" ;;
    CLOSE) dehydrate_context "build-artifacts" ;;
    INGEST) ingest_context "$INGEST_DIR" ;;
    LIST) display_folders $(get_active_folder) ;;
    SWITCH) switch_context "$CONTEXT_NAME" ;;
esac