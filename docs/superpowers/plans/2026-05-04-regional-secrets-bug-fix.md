# Regional Secrets Bug Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the `is_regional` assignment bug in `scripts/instance-context.sh` so that it accurately reflects successful regional secret creation and fails fast if creation fails entirely.

**Architecture:** We are surgically modifying the `gsm_put` function in `scripts/instance-context.sh`. We will update the nested `if` statements that handle `gcloud secrets create` to check the command's exit status. If regional creation fails, it will now throw a `pretty_print` error and return 1, preventing the script from attempting to add a secret version to a non-existent secret path.

**Tech Stack:** Bash

---

### Task 1: Update `gsm_put` Logic in `scripts/instance-context.sh`

**Files:**
- Modify: `scripts/instance-context.sh` (specifically the `gsm_put` function around line 160)

- [ ] **Step 1: Replace the buggy logic in `gsm_put`**

Modify `scripts/instance-context.sh`. Locate the `local is_regional=false` declaration in the `gsm_put` function and replace the subsequent `if/else` block with the improved logic.

Replace:
```bash
    local is_regional=false

    if ! gcloud secrets describe "${secret_name}" --project="${p_id}" &>/dev/null; then
        # Try describing regionally if global fails, to see if it exists regionally
        if [[ -n "$reg" ]] && gcloud secrets describe "${secret_name}" --project="${p_id}" --location="${reg}" &>/dev/null; then
            is_regional=true
        else
            # Doesn't exist globally or regionally. Try creating globally first.
            if ! gcloud secrets create "${secret_name}" --replication-policy="automatic" ${labels} --project="${p_id}" &>/dev/null; then
                # If global creation fails, try regional creation
                if [[ -n "$reg" ]]; then
                    gcloud secrets create "${secret_name}" --replication-policy="user-managed" --location="${reg}" ${labels} --project="${p_id}" &>/dev/null
                    is_regional=true
                fi
            fi
        fi
    fi
```

With:
```bash
    local is_regional=false

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
```

- [ ] **Step 2: Syntax Check the Bash Script**

Run: `bash -n scripts/instance-context.sh`
Expected: Empty output (no syntax errors)

- [ ] **Step 3: Run existing unit test script**

Run: `./tests/test_instance_context.sh`
Expected: The tests should pass (or at least fail for reasons unrelated to syntax errors in `instance-context.sh`, as this is an existing test suite). Note: If the test suite requires a specific mocked environment that isn't set up, verify the syntax check from Step 2 as the primary validation.

- [ ] **Step 4: Commit**

```bash
git add scripts/instance-context.sh
git commit -m "fix: regional secret creation logic in gsm_put

Only sets is_regional=true if the regional secret creation successfully
executes. If both global and regional secret creation attempts fail,
the script fails fast, logs a clear error message, and aborts the
gsm_put operation to prevent cascading INVALID_ARGUMENT failures."
```
