# Key File Trimming Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ensure that private and public key files do not contain trailing spaces and end with exactly one newline during context hydration and generation.

**Architecture:** Create a shared shell helper function `trim_key_file` in `scripts/shell-install-helper.sh` that uses `sed` to remove trailing whitespace and trailing newlines, then appends exactly one newline. Update all key file handling locations in `scripts/instance-context.sh` and `setup.sh` to call this function.

**Tech Stack:** Bash, sed

---

### Task 1: Create shared trim function and write tests

**Files:**
- Modify: `scripts/shell-install-helper.sh`
- Modify: `tests/test_instance_context.sh` (or create a new test file if better suited)

- [ ] **Step 1: Add trim function to helper script**

Add the `trim_key_file` function to the end of `scripts/shell-install-helper.sh`.

```bash
function trim_key_file() {
    local target_file="$1"
    if [[ -f "$target_file" ]]; then
        # Remove trailing whitespace from all lines
        sed -i 's/[[:space:]]*$//' "$target_file"
        # Remove all trailing blank lines
        sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$target_file"
        # Ensure exactly one newline at EOF
        echo "" >> "$target_file"
    fi
}
```

- [ ] **Step 2: Add test cases to existing test suite**

Add a test section to `tests/test_instance_context.sh` to verify the trim function works correctly.

```bash
# Test trim_key_file function
echo "Testing trim_key_file..."
source scripts/shell-install-helper.sh

# Case 1: Trailing spaces and multiple newlines
cat << 'EOF' > test_key.txt
test-key  
line 2   

EOF
trim_key_file test_key.txt
cat -e test_key.txt > test_key_out.txt
if ! grep -q "line 2$" test_key_out.txt; then
    echo "FAIL: trim_key_file failed to trim trailing spaces and newlines"
    exit 1
fi
rm test_key.txt test_key_out.txt
echo "PASS: trim_key_file works as expected"
```

- [ ] **Step 3: Run the test to verify it passes**

Run: `./tests/test_instance_context.sh`
Expected: Output includes "Testing trim_key_file..." and "PASS: trim_key_file works as expected"

- [ ] **Step 4: Commit**

```bash
git add scripts/shell-install-helper.sh tests/test_instance_context.sh
git commit -m "feat: add robust trim_key_file function and tests"
```

### Task 2: Apply trim function to scripts/instance-context.sh

**Files:**
- Modify: `scripts/instance-context.sh`

- [ ] **Step 1: Update hydrate_context to trim fetched keys**

In `scripts/instance-context.sh` around line 265, after the keys are fetched via `gsm_get`:

```bash
    # Fetch/Ensure Files
    gsm_get "gdc-${cl_name}-ssh-key" "$p_id" > "$target_dir/consumer-edge-machine"
    trim_key_file "$target_dir/consumer-edge-machine"
    chmod 400 "$target_dir/consumer-edge-machine"
    gsm_get "gdc-${cl_name}-ssh-key-pub" "$p_id" > "$target_dir/consumer-edge-machine.pub"
    trim_key_file "$target_dir/consumer-edge-machine.pub"
    chmod 644 "$target_dir/consumer-edge-machine.pub"
```

- [ ] **Step 2: Update create_context_from_yaml to trim fetched/generated keys**

In `scripts/instance-context.sh` around line 718, update the `existing_ssh` check block:

```bash
    # 4. Handle SSH Keys
    local existing_ssh=$(gsm_get "gdc-${cl_name}-ssh-key" "$p_id")
    if [[ -n "$existing_ssh" ]]; then
        pretty_print "Existing SSH key found in GSM, using it." "INFO"
        echo "$existing_ssh" > "$target/consumer-edge-machine"
        trim_key_file "$target/consumer-edge-machine"
        chmod 600 "$target/consumer-edge-machine"
        gsm_get "gdc-${cl_name}-ssh-key-pub" "$p_id" > "$target/consumer-edge-machine.pub"
        trim_key_file "$target/consumer-edge-machine.pub"
    else
        pretty_print "No SSH key found in GSM, generating new pair..." "INFO"
        ssh-keygen -t rsa -b 4096 -f "$target/consumer-edge-machine" -N "" -q
        trim_key_file "$target/consumer-edge-machine"
        trim_key_file "$target/consumer-edge-machine.pub"
        # Push new keys to GSM later in step 6
    fi
```

- [ ] **Step 3: Run the test suite**

Run: `./tests/test_instance_context.sh`
Expected: Output includes test passes and no syntax errors are introduced.

- [ ] **Step 4: Commit**

```bash
git add scripts/instance-context.sh
git commit -m "fix: apply trim_key_file to instance-context hydration and generation"
```

### Task 3: Apply trim function to setup.sh

**Files:**
- Modify: `setup.sh`

- [ ] **Step 1: Ensure shell-install-helper.sh is sourced**

`setup.sh` already has `source scripts/shell-install-helper.sh` or equivalent at the top, so `trim_key_file` is available. Verify this visually.

- [ ] **Step 2: Update setup.sh to trim keys**

In `setup.sh` around line 59, update the key fetching logic:

```bash
    		pretty_print "\nINFO: Downloading key for ${SECRET_LIST[$index]#}" "INFO"
            gcloud secrets versions access latest --secret="${SECRET_LIST[$index]}" >> ./build-artifacts/consumer-edge-machine --project="${PROJECT_ID}"
            trim_key_file "./build-artifacts/consumer-edge-machine"
			chmod 600 ./build-artifacts/consumer-edge-machine
            pretty_print "INFO: Generate the public key locally ./build-artifacts/consumer-edge-machine.pub" "INFO"
            ssh-keygen -f ./build-artifacts/consumer-edge-machine -y >> ./build-artifacts/consumer-edge-machine.pub
            trim_key_file "./build-artifacts/consumer-edge-machine.pub"
        else
            echo -e "\nINFO: Creating a new SSH key-pair and pushing to Google Secret Manager for Cluster '${DEFAULT_CLUSTER_NAME}'"
            echo "INFO: The new primary key stored at ./build-artifacts/consumer-edge-machine.pub"

            ssh-keygen -o -a 100 -t ed25519 -f ./build-artifacts/consumer-edge-machine -N ''
            trim_key_file "./build-artifacts/consumer-edge-machine"
            trim_key_file "./build-artifacts/consumer-edge-machine.pub"
            gcloud secrets create ssh-priv-key-${DEFAULT_CLUSTER_NAME} --replication-policy="automatic" > /dev/null 2>&1 # Ignore all issues with this
            gcloud secrets versions add ssh-priv-key-${DEFAULT_CLUSTER_NAME} --data-file="build-artifacts/consumer-edge-machine" > /dev/null 2>&1
        fi
```
*(Note: changed `echo "\nINFO..."` to `echo -e "\nINFO..."` if it was standard `echo` above, but primarily focusing on adding `trim_key_file`)*

- [ ] **Step 3: Run the test suite**

Run: `./tests/test_instance_context.sh`
Expected: Output includes test passes. (We don't have a specific `setup.sh` test, but ensuring no bash syntax errors is key).

- [ ] **Step 4: Commit**

```bash
git add setup.sh
git commit -m "fix: apply trim_key_file to setup.sh key fetching and generation"
```
