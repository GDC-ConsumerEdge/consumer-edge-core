# Sed-to-Awk/Yq Refactoring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate all usage of `sed -i` in `scripts/instance-context.sh` to ensure macOS compatibility, replacing it with `awk` for text files and `yq` for YAML files.

**Architecture:** Use `awk` with temporary file redirection for `.envrc` and `yq e -i` for in-place YAML updates.

**Tech Stack:** Bash, Awk, Yq (mikefarah/yq v4)

---

### Task 1: Refactor `dehydrate_context` (envrc Scrubbing)

**Files:**
- Modify: `scripts/instance-context.sh`

- [ ] **Step 1: Replace sed with awk in `dehydrate_context`**

Modify `dehydrate_context` function. Replace the 4 `sed -i` lines with a single `awk` pass.

```bash
    # 2. Scrub envrc
    if [[ -f "$target_dir/envrc" ]]; then
        local closed="****closed*******"
        awk -v closed="$closed" '{
            gsub(/.*SCM_TOKEN_USER=.*/, "export SCM_TOKEN_USER=\""closed"\"");
            gsub(/.*SCM_TOKEN_TOKEN=.*/, "export SCM_TOKEN_TOKEN=\""closed"\"");
            gsub(/.*OIDC_CLIENT_ID=.*/, "export OIDC_CLIENT_ID=\""closed"\"");
            gsub(/.*OIDC_CLIENT_SECRET=.*/, "export OIDC_CLIENT_SECRET=\""closed"\"");
            print
        }' "$target_dir/envrc" > "$target_dir/envrc.tmp" && mv "$target_dir/envrc.tmp" "$target_dir/envrc"
    fi
```

- [ ] **Step 2: Commit**

```bash
git add scripts/instance-context.sh
git commit -m "refactor: use awk for envrc scrubbing in dehydrate_context"
```

---

### Task 2: Refactor `hydrate_context` (envrc Injection)

**Files:**
- Modify: `scripts/instance-context.sh`

- [ ] **Step 1: Replace sed with awk in `hydrate_context`**

Locate the injection block in `hydrate_context`.

```bash
    # Inject into envrc
    if [[ -n "$scm_user" || -n "$scm_token" || -n "$oidc_id" || -n "$oidc_secret" ]]; then
        awk -v scm_u="$scm_user" -v scm_t="$scm_token" -v oidc_i="$oidc_id" -v oidc_s="$oidc_secret" '{
            if (scm_u != "" && $0 ~ /SCM_TOKEN_USER=/) $0 = "export SCM_TOKEN_USER=\""scm_u"\""
            if (scm_t != "" && $0 ~ /SCM_TOKEN_TOKEN=/) $0 = "export SCM_TOKEN_TOKEN=\""scm_t"\""
            if (oidc_i != "" && $0 ~ /OIDC_CLIENT_ID=/) $0 = "export OIDC_CLIENT_ID=\""oidc_i"\""
            if (oidc_s != "" && $0 ~ /OIDC_CLIENT_SECRET=/) $0 = "export OIDC_CLIENT_SECRET=\""oidc_s"\""
            print
        }' "$target_dir/envrc" > "$target_dir/envrc.tmp" && mv "$target_dir/envrc.tmp" "$target_dir/envrc"
    fi
```

- [ ] **Step 2: Commit**

```bash
git add scripts/instance-context.sh
git commit -m "refactor: use awk for envrc injection in hydrate_context"
```

---

### Task 3: Refactor `ingest_context` (YAML Template Generation)

**Files:**
- Modify: `scripts/instance-context.sh`

- [ ] **Step 1: Convert `ingest_context` sed calls to yq**

In `ingest_context`, replace the block of `sed` updates for `yaml_out` with `yq` commands.

```bash
    # Update core values using yq
    yq e -i ".context_name = \"${name}\"" "$yaml_out"
    yq e -i ".cluster_name = \"${cl_name}\"" "$yaml_out"
    yq e -i ".project_id = \"${p_id}\"" "$yaml_out"

    if [[ -n "$reg" ]]; then yq e -i ".region = \"${reg}\"" "$yaml_out"; fi
    if [[ -n "$zn" ]]; then yq e -i ".zone = \"${zn}\"" "$yaml_out"; fi

    if [[ -n "$cp_vip" && "$cp_vip" != "null" ]]; then yq e -i ".control_plane_vip = \"${cp_vip}\"" "$yaml_out"; fi
    if [[ -n "$in_vip" && "$in_vip" != "null" ]]; then yq e -i ".ingress_vip = \"${in_vip}\"" "$yaml_out"; fi
    if [[ -n "$lb_pool" && "$lb_pool" != "null" ]]; then yq e -i ".load_balancer_pool_cidr = \"${lb_pool}\"" "$yaml_out"; fi

    if [[ -n "$repo_url" && "$repo_url" != "null" ]]; then yq e -i ".root_repo_url = \"${repo_url}\"" "$yaml_out"; fi
    if [[ -n "$repo_branch" && "$repo_branch" != "null" ]]; then yq e -i ".root_repo_branch = \"${repo_branch}\"" "$yaml_out"; fi

    if [[ -n "$storage" && "$storage" != "null" ]]; then yq e -i ".storage_provider = \"${storage}\"" "$yaml_out"; fi
    if [[ -n "$abm_ver" && "$abm_ver" != "null" ]]; then yq e -i ".abm_version = \"${abm_ver}\"" "$yaml_out"; fi
    if [[ -n "$acm_ver" && "$acm_ver" != "null" ]]; then yq e -i ".acm_version = \"${acm_ver}\"" "$yaml_out"; fi

    if [[ "$storage" == "robin" ]]; then
        # ... (keep existing robin disk logic which already uses yq) ...
        if [[ -n "$robin_bundle" && "$robin_bundle" != "null" ]]; then
             yq e -i ".robin_install_bundle_file = \"${robin_bundle}\"" "$yaml_out"
        fi
    fi
```

- [ ] **Step 2: Commit**

```bash
git add scripts/instance-context.sh
git commit -m "refactor: use yq for yaml updates in ingest_context"
```

---

### Task 4: Refactor `generate_context` (envrc & inventory)

**Files:**
- Modify: `scripts/instance-context.sh`

- [ ] **Step 1: Replace sed with awk for `envrc` generation**

In `generate_context`, replace the `sed` block for `$target/envrc`.

```bash
    # Replace the block around line 784
    awk -v p_id="$p_id" -v reg="$reg" -v zn="$zn" -v cl_name="$cl_name" -v r_url="$root_repo_url" -v r_branch="$root_repo_branch" '
    BEGIN { print "# This file sets environment variables for the cluster provisioning run." }
    {
        gsub(/export PROJECT_ID=.*/, "export PROJECT_ID=\""p_id"\" # GCP Project ID (from YAML project_id)")
        gsub(/export REGION=.*/, "export REGION=\""reg"\" # GCP Region (from YAML region)")
        gsub(/export ZONE=.*/, "export ZONE=\""zn"\" # GCP Zone (from YAML zone)")
        gsub(/export CLUSTER_ACM_NAME=.*/, "export CLUSTER_ACM_NAME=\""cl_name"\" # Cluster name used by ACM (from YAML cluster_name)")
        gsub(/export ROOT_REPO_URL=.*/, "export ROOT_REPO_URL=\""r_url"\" # Root SCM Repo")
        gsub(/export ROOT_REPO_BRANCH=.*/, "export ROOT_REPO_BRANCH=\""r_branch"\"")
        print
    }
    ' "$target/envrc" > "$target/envrc.tmp" && mv "$target/envrc.tmp" "$target/envrc"
```

- [ ] **Step 2: Replace sed with yq line_comment for `inventory.yaml`**

Replace lines 818-820.

```bash
    yq e -i ".[\"${cl_name}_cluster\"].vars.cluster_name line_comment=\"Name of the cluster (from YAML cluster_name)\"" "$target/inventory.yaml"
    yq e -i ".[\"${cl_name}_cluster\"].vars.control_plane_vip line_comment=\"K8s API endpoint (from YAML control_plane_vip)\"" "$target/inventory.yaml"
    yq e -i ".[\"${cl_name}_cluster\"].vars.ingress_vip line_comment=\"Entry point for services (from YAML ingress_vip)\"" "$target/inventory.yaml"
```

- [ ] **Step 3: Replace sed with yq for `instance-run-vars.yaml`**

Replace the block around line 856-902.

```bash
    # Insert header
    awk "BEGIN{print \"# Variables specific to this provisioning run (e.g. storage provider)\"}1" "$target/instance-run-vars.yaml" > "$target/instance-run-vars.tmp" && mv "$target/instance-run-vars.tmp" "$target/instance-run-vars.yaml"

    if [[ -n "$storage_provider" && "$storage_provider" != "null" ]]; then
        yq e -i ".storage_provider = \"${storage_provider}\"" "$target/instance-run-vars.yaml"
        # ... (keep robin disk paths logic as it uses yq) ...
    fi

    if [[ -n "$abm_version" && "$abm_version" != "null" ]]; then
        yq e -i ".abm_version = \"${abm_version}\"" "$target/instance-run-vars.yaml"
    fi

    if [[ -n "$acm_version" && "$acm_version" != "null" ]]; then
        yq e -i ".acm_version = \"${acm_version}\"" "$target/instance-run-vars.yaml"
    fi

    if [[ "$storage_provider" == "robin" && -n "$robin_bundle" && "$robin_bundle" != "null" ]]; then
        yq e -i ".robin_install_bundle_file = \"${robin_bundle}\"" "$target/instance-run-vars.yaml"
    fi
```

- [ ] **Step 4: Commit**

```bash
git add scripts/instance-context.sh
git commit -m "refactor: use awk and yq for context generation"
```

---

### Task 5: Verification

- [ ] **Step 1: Run Syntax Check**

Run: `bash -n scripts/instance-context.sh`
Expected: Success

- [ ] **Step 2: Generate Context**

Run: `./scripts/instance-context.sh -r us-west1 -g configs/cascade-config.yaml cascade` (Choose 'y' to create)
Verify files:
- `build-artifacts-cascade/envrc`: Check values
- `build-artifacts-cascade/inventory.yaml`: Check comments
- `build-artifacts-cascade/instance-run-vars.yaml`: Check values

- [ ] **Step 3: Scrub Check**

Run: `./scripts/instance-context.sh -x cascade`
Verify `build-artifacts-cascade/envrc`: Tokens should be `****closed*******`
