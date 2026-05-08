# Optional OIDC Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make OIDC settings optional in `instance-context.sh` by toggling their commented-out state in `envrc` based on their presence in GSM.

**Architecture:** Update `ingest_context`, `hydrate_context`, and `dehydrate_context` in `scripts/instance-context.sh` using anchored `grep` and state-aware `awk` logic.

**Tech Stack:** Bash, awk

---

### Task 1: Create Reproduction/Verification Test

**Files:**
- Create: `tests/test_oidc_optionality.sh`

- [ ] **Step 1: Write the verification test**

```bash
#!/bin/bash
# tests/test_oidc_optionality.sh
source scripts/shell-install-helper.sh

test_dir="build-artifacts-oidc-test"
rm -rf "$test_dir"
mkdir -p "$test_dir"

cat << EOF > "$test_dir/envrc"
export PROJECT_ID="test-project"
export REGION="us-central1"
export CLUSTER_ACM_NAME="oidc-test"
# export OIDC_CLIENT_ID=""
# export OIDC_CLIENT_SECRET=""
# export OIDC_USER=""
export OIDC_ENABLED="false"
EOF

# Mock gsm_get and gsm_put to avoid actual network calls
function gsm_get() { echo ""; }
function gsm_put() { echo "MOCKED PUT: $@"; }
export -f gsm_get gsm_put

echo "Testing Ingestion with commented OIDC..."
source scripts/instance-context.sh
# Extract variables manually to simulate ingest_context logic
oidc_id=$(grep "^export OIDC_CLIENT_ID=" "$test_dir/envrc" | cut -d'"' -f2)
if [[ -n "$oidc_id" ]]; then
    echo "FAIL: Ingested commented OIDC_CLIENT_ID"
    exit 1
fi
echo "PASS: Commented OIDC ignored during ingest"

echo "Testing Hydration with missing OIDC secrets..."
# Simulate hydrate_context logic on a file that has it uncommented but "closed"
cat << EOF > "$test_dir/envrc"
export CLUSTER_ACM_NAME="oidc-test"
export PROJECT_ID="test-project"
export REGION="us-central1"
export OIDC_CLIENT_ID="****closed*******"
export OIDC_CLIENT_SECRET="****closed*******"
export OIDC_USER="****closed*******"
export OIDC_ENABLED="true"
EOF

# Logic to be implemented
# hydrate_context "$test_dir" (using mocks)
# For now, we expect this test to fail until Task 2 is complete
```

- [ ] **Step 2: Run test to verify initial state**

Run: `bash tests/test_oidc_optionality.sh`
Expected: Should show PASS for ingest (if we fix it first) but FAIL/Incomplete for hydration.

- [ ] **Step 3: Commit test**

```bash
git add tests/test_oidc_optionality.sh
git commit -m "test: add OIDC optionality verification script"
```

---

### Task 2: Refactor Ingestion Logic

**Files:**
- Modify: `scripts/instance-context.sh:580-590` (approx)

- [ ] **Step 1: Update `ingest_context` to use anchored grep**

```bash
# Inside ingest_context function in scripts/instance-context.sh
    local scm_user=$(grep "^export SCM_TOKEN_USER=" "$target_dir/envrc" | cut -d'"' -f2)
    local scm_token=$(grep "^export SCM_TOKEN_TOKEN=" "$target_dir/envrc" | cut -d'"' -f2)
    local oidc_id=$(grep "^export OIDC_CLIENT_ID=" "$target_dir/envrc" | cut -d'"' -f2)
    local oidc_secret=$(grep "^export OIDC_CLIENT_SECRET=" "$target_dir/envrc" | cut -d'"' -f2)
    local oidc_user=$(grep "^export OIDC_USER=" "$target_dir/envrc" | cut -d'"' -f2)
```

- [ ] **Step 2: Update `ingest_context` to handle `oidc_user`**

```bash
    if [[ -n "$oidc_id" && "$oidc_id" != "****closed*******" ]]; then gsm_put "gdc-${cl_name}-oidc-id" "$oidc_id" "$cl_name" "$p_id" "$reg"; fi
    if [[ -n "$oidc_secret" && "$oidc_secret" != "****closed*******" ]]; then gsm_put "gdc-${cl_name}-oidc-secret" "$oidc_secret" "$cl_name" "$p_id" "$reg"; fi
    if [[ -n "$oidc_user" && "$oidc_user" != "****closed*******" ]]; then gsm_put "gdc-${cl_name}-oidc-user" "$oidc_user" "$cl_name" "$p_id" "$reg"; fi
```

- [ ] **Step 3: Verify with test**

Run: `bash tests/test_oidc_optionality.sh`
Expected: PASS for Ingestion section.

- [ ] **Step 4: Commit**

```bash
git add scripts/instance-context.sh
git commit -m "feat: use anchored grep in ingest_context for optional vars"
```

---

### Task 3: Refactor Hydration Logic

**Files:**
- Modify: `scripts/instance-context.sh:510-530` (approx)

- [ ] **Step 1: Update `hydrate_context` to toggle comments**

```bash
# Inside hydrate_context function in scripts/instance-context.sh
    # Fetch envrc vars
    local scm_user=$(gsm_get "gdc-${cl_name}-scm-user" "$p_id" "$reg")
    local scm_token=$(gsm_get "gdc-${cl_name}-scm-token" "$p_id" "$reg")
    local oidc_id=$(gsm_get "gdc-${cl_name}-oidc-id" "$p_id" "$reg")
    local oidc_secret=$(gsm_get "gdc-${cl_name}-oidc-secret" "$p_id" "$reg")
    local oidc_user=$(gsm_get "gdc-${cl_name}-oidc-user" "$p_id" "$reg")

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
```

- [ ] **Step 2: Update test to verify hydration**

Add hydration check to `tests/test_oidc_optionality.sh`.

- [ ] **Step 3: Run test**

Run: `bash tests/test_oidc_optionality.sh`
Expected: PASS for Hydration section.

- [ ] **Step 4: Commit**

```bash
git add scripts/instance-context.sh tests/test_oidc_optionality.sh
git commit -m "feat: toggle OIDC comments and OIDC_ENABLED during hydration"
```

---

### Task 4: Refactor Dehydration Logic

**Files:**
- Modify: `scripts/instance-context.sh:425-435` (approx)

- [ ] **Step 1: Update `dehydrate_context` to preserve comments**

```bash
# Inside dehydrate_context function in scripts/instance-context.sh
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
```

- [ ] **Step 2: Update test to verify dehydration**

Add dehydration check to `tests/test_oidc_optionality.sh`.

- [ ] **Step 3: Run test**

Run: `bash tests/test_oidc_optionality.sh`
Expected: PASS for all sections.

- [ ] **Step 4: Commit**

```bash
git add scripts/instance-context.sh tests/test_oidc_optionality.sh
git commit -m "feat: preserve comment status during dehydration"
```
