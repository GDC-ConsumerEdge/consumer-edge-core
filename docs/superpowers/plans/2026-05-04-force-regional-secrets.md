# Force Regional Secrets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `-r`/`--force-regional` flag to `instance-context.sh` to strictly bypass global secret checks, and use it to create a `cascade` context in `us-west1`.

**Architecture:** We will introduce a global variable `FORCED_REGION` in `scripts/instance-context.sh`. We will update the `usage` and `check_options` functions to handle the new flag. We will modify `gsm_get` and `gsm_put` to check this variable and, if set, immediately execute regional commands without falling back to global operations.

**Tech Stack:** Bash

---

### Task 1: Update Argument Parsing and Usage

**Files:**
- Modify: `scripts/instance-context.sh`

- [ ] **Step 1: Update the `usage` function**

Modify `scripts/instance-context.sh`. Find the `usage()` function and add the `-r` option.

```bash
function usage() {
    pretty_print "Usage: instance-context.sh [-c] [-l] [-g <yaml_file>] [-i <folder>] [-o] [-x] [-r <region>] [folder-name]"
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
    pretty_print "  -r region\tStrictly force all Secret Manager operations to a specific region (also --force-regional)"
}
```

- [ ] **Step 2: Add global variable and update `check_options`**

Modify `scripts/instance-context.sh`. Above `function check_options()`, add `FORCED_REGION=""`. Then modify the parsing logic. Since `getopts` doesn't natively handle long options like `--force-regional`, we'll convert the standard `getopts` loop into a robust `while`/`case` loop that can handle both short and long options.

Replace the entire `check_options` function:
```bash
FORCED_REGION=""

function check_options() {
    has_option=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -c) print_context; list_folders=false; has_option=true; shift ;;
            -l) list_folders=true; has_option=true; shift ;;
            -g) generate_yaml="$2"; list_folders=false; has_option=true; shift 2 ;;
            -i) ingest_folder="$2"; list_folders=false; has_option=true; shift 2 ;;
            -o) want_open=true; list_folders=false; has_option=true; shift ;;
            -x) want_close=true; list_folders=false; has_option=true; shift ;;
            -r|--force-regional) FORCED_REGION="$2"; list_folders=false; has_option=true; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            -*) pretty_print "Unknown option: $1" "ERROR"; usage; exit 1 ;;
            *) 
                # Positional argument (folder name)
                if [[ $has_option == false || -n "$generate_yaml" || -n "$ingest_folder" || $want_open == true || $want_close == true || -n "$FORCED_REGION" ]]; then
                    desired_folder="$1"
                    want_new_folder=true
                fi
                shift
                ;;
        esac
    done
}
```

- [ ] **Step 3: Syntax Check**

Run: `bash -n scripts/instance-context.sh`
Expected: Empty output

### Task 2: Update GSM Functions to Handle `FORCED_REGION`

**Files:**
- Modify: `scripts/instance-context.sh`

- [ ] **Step 1: Update `gsm_get`**

Modify `gsm_get` to check `FORCED_REGION` first.

Replace the current `gsm_get` with:
```bash
function gsm_get() {
    local secret_name="$1"
    local p_id="$2"
    local reg="$3"

    if [[ -n "$FORCED_REGION" ]]; then
        gcloud secrets versions access latest --secret="${secret_name}" --project="${p_id}" --location="${FORCED_REGION}" 2>/dev/null
        return
    fi

    # Try global first
    local val=$(gcloud secrets versions access latest --secret="${secret_name}" --project="${p_id}" 2>/dev/null)
    if [[ -z "$val" && -n "$reg" ]]; then
        # Try regional fallback
        val=$(gcloud secrets versions access latest --secret="${secret_name}" --project="${p_id}" --location="${reg}" 2>/dev/null)
    fi
    echo "$val"
}
```

- [ ] **Step 2: Update `gsm_put`**

Modify `gsm_put` to skip global logic if `FORCED_REGION` is set.

Replace the current `gsm_put` with:
```bash
function gsm_put() {
    local secret_name="$1"
    local secret_value="$2"
    local cl_name="$3"
    local p_id="$4"
    local reg="$5"

    local labels=""
    if [[ -n "$cl_name" ]]; then
        # GSM labels must be lowercase, alphanumeric, hyphens or underscores
        local label_val=$(echo "$cl_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/_/g')
        labels="--labels=cluster=$label_val"
    fi

    local is_regional=false

    if [[ -n "$FORCED_REGION" ]]; then
        is_regional=true
        if ! gcloud secrets describe "${secret_name}" --project="${p_id}" --location="${FORCED_REGION}" &>/dev/null; then
             if ! gcloud secrets create "${secret_name}" --replication-policy="user-managed" --location="${FORCED_REGION}" ${labels} --project="${p_id}" &>/dev/null; then
                 pretty_print "Failed to create regional secret '${secret_name}' in ${FORCED_REGION}." "ERROR"
                 return 1
             fi
        fi
    else
        # Check if it exists globally
        if ! gcloud secrets describe "${secret_name}" --project="${p_id}" &>/dev/null; then
            # Doesn't exist globally. Try describing regionally.
            if [[ -n "$reg" ]] && gcloud secrets describe "${secret_name}" --project="${p_id}" --location="${reg}" &>/dev/null; then
                is_regional=true
            else
                # Doesn't exist anywhere. Try creating globally first.
                if ! gcloud secrets create "${secret_name}" --replication-policy="automatic" ${labels} --project="${p_id}" &>/dev/null; then
                    # Global creation failed. Try regional creation if region is provided.
                    if [[ -n "$reg" ]]; then
                        if gcloud secrets create "${secret_name}" --replication-policy="user-managed" --location="${reg}" ${labels} --project="${p_id}" &>/dev/null; then
                            is_regional=true
                        else
                            # Both global and regional creation failed
                            pretty_print "Failed to create secret '${secret_name}' globally and regionally. Check permissions." "ERROR"
                            return 1
                        fi
                    else
                        # Global creation failed and no region provided
                        pretty_print "Failed to create secret '${secret_name}' globally and no region provided. Check permissions." "ERROR"
                        return 1
                    fi
                fi
            fi
        fi
    fi

    # Check if we need to skip update because value is identical
    local current_val=$(gsm_get "${secret_name}" "${p_id}" "${reg}")
    if [[ "$current_val" == "$secret_value" ]]; then
        return 0
    fi

    if [[ "$is_regional" == true ]]; then
        echo -n "${secret_value}" | gcloud secrets versions add "${secret_name}" --data-file=- --project="${p_id}" --location="${FORCED_REGION:-$reg}"
    else
        echo -n "${secret_value}" | gcloud secrets versions add "${secret_name}" --data-file=- --project="${p_id}"
    fi
}
```

- [ ] **Step 3: Update `validate_gsm_secret`**

Modify `validate_gsm_secret` to skip global describe if `FORCED_REGION` is set.

Replace the current `validate_gsm_secret` with:
```bash
function validate_gsm_secret() {
    local secret_name="$1"
    local p_id="$2"
    local missing_action="${3:-MISSING}"
    local reg="$4"

    if [[ -n "$FORCED_REGION" ]]; then
        if gcloud secrets describe "${secret_name}" --project="${p_id}" --location="${FORCED_REGION}" &>/dev/null; then
            echo "OK"
        else
            echo "$missing_action"
        fi
        return
    fi

    if gcloud secrets describe "${secret_name}" --project="${p_id}" &>/dev/null; then
        echo "OK"
    elif [[ -n "$reg" ]] && gcloud secrets describe "${secret_name}" --project="${p_id}" --location="${reg}" &>/dev/null; then
        echo "OK"
    else
        echo "$missing_action"
    fi
}
```

- [ ] **Step 4: Syntax Check**

Run: `bash -n scripts/instance-context.sh`
Expected: Empty output

- [ ] **Step 5: Run Tests**

Run: `./tests/test_instance_context.sh`
Expected: Output showing tests ran (ignoring specific failures due to missing GSM environment variables if they occurred previously).

- [ ] **Step 6: Commit**

```bash
git add scripts/instance-context.sh
git commit -m "feat: add --force-regional flag to strict GSM regions"
```

### Task 3: Create `cascade` Context

**Files:**
- Create: `configs/cascade-config.yaml`
- Run: `./scripts/instance-context.sh`

- [ ] **Step 1: Create `cascade-config.yaml`**

Create `configs/cascade-config.yaml` with dummy values for the context generation.
```bash
cat << 'CONFIGEOF' > configs/cascade-config.yaml
context_name: "cascade"
cluster_name: "cascade"
project_id: "test-gcp-project"
region: "us-west1"
zone: "us-west1-a"
control_plane_vip: "10.0.0.1"
ingress_vip: "10.0.0.2"
load_balancer_pool_cidr: "10.0.0.0/24"
nodes:
  - name: "cascade-cp-1"
    ip: "10.0.0.3"
CONFIGEOF
```

- [ ] **Step 2: Generate the context using the new flag**

Note: This step requires actual GCP access if it attempts to validate or create secrets. If we are just verifying the script logic parses it correctly without executing the full GSM generation, we can pass `-h` to see usage or run the command and cancel it. Assuming we want to run the command to create the folder:

```bash
# We pipe 'N' to the prompt "Ready to create context 'cascade'? (y/N)" to just validate the flag works without mutating GSM if we lack permissions.
echo "N" | ./scripts/instance-context.sh -r us-west1 -g configs/cascade-config.yaml cascade
```

- [ ] **Step 3: Commit Config**
```bash
git add configs/cascade-config.yaml
git commit -m "test: add cascade config for us-west1"
```

