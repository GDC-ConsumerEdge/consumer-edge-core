# Design Spec: Forced Regional Secrets via CLI Flag

## Status
Proposed

## Context
The current `instance-context.sh` script uses a "global-first, then regional" fallback strategy for Google Secret Manager (GSM). While functional, this is inefficient when a user explicitly knows they want to use regional secrets (e.g., for data residency or policy reasons). We need a way to force the script to use a specific region for all GSM operations, skipping the global checks entirely.

We also need to set up a new context named `cascade` that strictly uses regional secrets in `us-west1`.

## Requirements
- Add a CLI flag `-r <region>` and `--force-regional <region>` to `scripts/instance-context.sh`.
- When this flag is used, all calls to `gsm_get` and `gsm_put` must bypass global checks and only interact with the specified region.
- `gsm_put` must create secrets with `user-managed` replication in the specified region if they don't exist.
- Update the help message to include the new flag.
- Create a new context `cascade` using this flag with region `us-west1`.

## Proposed Architecture / Logic Changes

### 1. Global Variable and Flag Parsing
A new global variable `FORCED_REGION` will be initialized to an empty string. The `check_options` function will be updated to parse `-r` and `--force-regional`.

```bash
FORCED_REGION=""

# In check_options...
while [[ $# -gt 0 ]]; do
    case "$1" in
        -r|--force-regional)
            FORCED_REGION="$2"
            shift 2
            ;;
        # ... other flags ...
    esac
done
```
*Note: Since the script currently uses `getopts`, I will update it to a hybrid loop that handles both `getopts` for short flags and manual parsing for the long flag and its value.*

### 2. `gsm_get` Update
```bash
function gsm_get() {
    local secret_name="$1"
    local p_id="$2"
    local reg="$3"

    if [[ -n "$FORCED_REGION" ]]; then
        gcloud secrets versions access latest --secret="${secret_name}" --project="${p_id}" --location="${FORCED_REGION}" 2>/dev/null
        return
    fi

    # ... existing fallback logic ...
}
```

### 3. `gsm_put` Update
```bash
function gsm_put() {
    # ... args ...
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
        # ... existing fallback logic (including the bug fix from previous task) ...
    fi
    
    # ... rest of function using $is_regional and $FORCED_REGION (or $reg) ...
}
```

## Verification Plan
1. **Flag Parsing**: Verify `./scripts/instance-context.sh -r us-west1` correctly sets the region.
2. **GSM Get**: Verify that with the flag, only regional `access` calls are made (can be seen via `--log-http` or by checking for 404s on global secrets).
3. **GSM Put**: Verify that with the flag, secrets are created with `user-managed` replication in the correct region.
4. **Context Creation**: Successfully run `./scripts/instance-context.sh -r us-west1 -g configs/cascade-config.yaml cascade` and verify it produces a functional (regional) context.
