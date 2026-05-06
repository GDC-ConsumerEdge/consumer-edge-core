# Instance Context Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Overhaul `scripts/instance-context.sh` to support explicit creation, downloading, and robust secret management via local overrides and interactive prompts.

**Architecture:** Refactor the script into a unified "Action-First" orchestrator. A centralized `SecretProvider` logic will handle the priority: `Local Override -> GSM -> Prompt`, ensuring all secrets are synced to GSM.

**Tech Stack:** Bash, `gcloud` CLI, `yq` (mikefarah version), `jq`.

---

### Task 1: Refactor Main Loop & Action Dispatcher

**Files:**
- Modify: `scripts/instance-context.sh`

- [ ] **Step 1: Define the ACTION variable and refactor flag parsing**
Replace the current flag parsing with a unified logic that sets a single `ACTION`.

```bash
ACTION="SWITCH" # Default
CONTEXT_NAME=""
YAML_FILE=""
INGEST_DIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c) ACTION="CREATE"; shift; CONTEXT_NAME="$1"; shift ;;
        -d) ACTION="DOWNLOAD"; shift; CONTEXT_NAME="$1"; shift ;;
        -o) ACTION="OPEN"; shift ;;
        -x) ACTION="CLOSE"; shift ;;
        -i) ACTION="INGEST"; shift; INGEST_DIR="$1"; shift ;;
        -l) ACTION="LIST"; shift ;;
        -r|--force-regional) FORCED_REGION="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        -*) echo "Unknown option: $1"; usage; exit 1 ;;
        *) CONTEXT_NAME="$1"; shift ;;
    esac
done
```

- [ ] **Step 2: Implement the Dispatcher**
Add a case statement at the bottom of the script to route to functions.

```bash
case "$ACTION" in
    CREATE) create_context "$CONTEXT_NAME" ;;
    DOWNLOAD) download_context "$CONTEXT_NAME" ;;
    OPEN) hydrate_context "build-artifacts" ;;
    CLOSE) dehydrate_context "build-artifacts" ;;
    INGEST) ingest_context "$INGEST_DIR" ;;
    LIST) display_folders $(get_active_folder) ;;
    SWITCH) switch_context "$CONTEXT_NAME" ;;
esac
```

- [ ] **Step 3: Commit**

```bash
git add scripts/instance-context.sh
git commit -m "refactor: introduce action-based dispatcher to instance-context.sh"
```

---

### Task 2: Implement the Secret Provider Logic

**Files:**
- Modify: `scripts/instance-context.sh`

- [ ] **Step 1: Implement `get_secret` with priority logic**
This function implements: `Local File -> GSM -> Prompt (if required)`.

```bash
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
```

- [ ] **Step 2: Commit**

```bash
git add scripts/instance-context.sh
git commit -m "feat: implement centralized Secret Provider with override and prompt logic"
```

---

### Task 3: Implement CREATE Action (`-c`)

**Files:**
- Modify: `scripts/instance-context.sh`

- [ ] **Step 1: Implement `create_context` function**
Scaffold files from templates based on the requirement table.

```bash
function create_context() {
    local name="$1"
    local target="build-artifacts-${name}"
    
    if [[ -d "$target" ]]; then
        pretty_print "Context ${name} already exists." "ERROR"
        exit 1
    fi

    pretty_print "Creating context ${name}..." "INFO"
    mkdir -p "$target"
    mkdir -p "configs"

    # 1. Copy Mapping (Simplified version of the table)
    cp build-artifacts-example/add-hosts-example "${target}/add-hosts"
    cp build-artifacts-example/ssh-config "${target}/ssh-config"
    cp templates/envrc-template.sh "${target}/envrc"
    cp templates/instance-run-vars-template.yaml "${target}/instance-run-vars.yaml"
    cp templates/inventory-physical-example.yaml "${target}/inventory.yaml"
    cp templates/context-config-template.yaml "configs/${name}-context.yaml"
    
    # ... handle SSH keys and GSAs using get_secret logic in Open task ...

    # 2. Update config YAML with name
    yq e -i ".context_name = \"${name}\"" "configs/${name}-context.yaml"
    
    pretty_print "Created configs/${name}-context.yaml. Please edit it." "SUCCESS"
    
    echo -n "Would you like to sync this config to GSM? (y/n): "
    read answer
    if [[ "$answer" == "y" ]]; then
        # Implementation of YAML sync to GSM
    fi
}
```

- [ ] **Step 2: Commit**

```bash
git add scripts/instance-context.sh
git commit -m "feat: implement explicit context creation logic"
```

---

### Task 4: Implement DOWNLOAD Action (`-d`)

**Files:**
- Modify: `scripts/instance-context.sh`

- [ ] **Step 1: Implement `download_context` function**
Retrieve YAML from GSM.

```bash
function download_context() {
    local name="$1"
    local p_id=$(gcloud config get-value project 2>/dev/null)
    local secret_name="context-${name}"

    pretty_print "Downloading context ${name} from GSM..." "INFO"
    local content=$(gcloud secrets versions access latest --secret="${secret_name}" --project="${p_id}" 2>/dev/null)
    
    if [[ -n "$content" ]]; then
        mkdir -p configs
        echo "$content" > "configs/${name}-context.yaml"
        pretty_print "Saved to configs/${name}-context.yaml" "SUCCESS"
    else
        pretty_print "Context configuration not found in Google Secret Manager with ${name} and ${p_id}" "ERROR"
        exit 1
    fi
}
```

- [ ] **Step 2: Commit**

```bash
git add scripts/instance-context.sh
git commit -m "feat: implement context download from GSM"
```

---

### Task 5: Implement Unified OPEN Logic (`-o`)

**Files:**
- Modify: `scripts/instance-context.sh`

- [ ] **Step 1: Update `hydrate_context` to use `get_secret`**
Refactor the hydration logic to go through the Secret Provider.

```bash
function hydrate_context() {
    # ... existing metadata extraction ...
    local cl_name=$(grep "export CLUSTER_ACM_NAME=" "$target_dir/envrc" | cut -d'"' -f2)
    local ctx_name=$(get_active_folder)

    # Example for SSH Key
    local ssh_key=$(get_secret "ssh_key" "gdc-${cl_name}-ssh-key" "true" "$p_id" "$reg" "$ctx_name")
    echo "$ssh_key" > "$target_dir/consumer-edge-machine"
    
    # Example for Optional OIDC
    local oidc_id=$(get_secret "oidc_id" "gdc-${cl_name}-oidc-id" "false" "$p_id" "$reg" "$ctx_name")
    # ... inject into envrc ...
}
```

- [ ] **Step 2: Commit**

```bash
git add scripts/instance-context.sh
git commit -m "feat: update hydration logic to use Secret Provider and overrides"
```

---

### Task 6: Final Integration & UX Polish

**Files:**
- Modify: `scripts/instance-context.sh`

- [ ] **Step 1: Update Usage Output**
Update the `usage` function to reflect the new flags and behavior.

- [ ] **Step 2: Test Switch Logic**
Ensure `./scripts/instance-context.sh [name]` still works for switching and prompts for creation if missing.

- [ ] **Step 3: Final Commit**

```bash
git add scripts/instance-context.sh
git commit -m "docs: update usage output and finalize overhaul"
```
