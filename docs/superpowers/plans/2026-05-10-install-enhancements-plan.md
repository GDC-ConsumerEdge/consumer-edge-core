# Install Enhancements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide a comprehensive installation summary and automate the handoff to the Docker installation phase.

**Architecture:** We will replace the manual `read` prompts at the end of `install.sh` with bash functions that extract configuration data from environment variables and inventory YAML files, display a summary box, and perform a 5-second countdown.

**Tech Stack:** Bash

---

### Task 1: Add YAML Extraction Helpers and Summary UI

**Files:**
- Modify: `install.sh`

- [ ] **Step 1: Replace the manual prompts with the extraction and summary logic**

Replace the block from `ACCEPT_OSS_MESSAGE=\`cat <<EOF` down to `if [[ "${proceed}" =~ ^([yY][eE][sS]|[yY])$ ]]; then` (inclusive) with the new logic. Note that we must also remove the `else` block that corresponds to the `if` statement we are removing, but we will handle the replacement carefully.

First, locate the OSS message block in `install.sh` and the subsequent conditionals, ending right before `pretty_print "Starting the installation"`.

Replace that entire section with the following code:

```bash
pretty_print "WARNING: This solution uses Open Source tools that are not explicitly covered by Google Support." "WARN"
pretty_print "         OSS solutions: External Secrets, Ansible Community" "WARN"
pretty_print "         Optional Tooling: kubens & kubectx, kubestr, K9s" "WARN"

function extract_yaml_value() {
    local key=\$1
    local file=\$2
    if [[ -f "\$file" ]]; then
        grep "^\${key}:" "\$file" | head -n 1 | sed -E "s/^\${key}:[[:space:]]*[\"']?([^\"']*)[\"']?.*$/\1/"
    fi
}

function get_var_value() {
    local key=\$1
    local val=""
    val=\$(extract_yaml_value "\$key" "build-artifacts/instance-run-vars.yaml")
    if [[ -n "\$val" ]]; then echo "\$val"; return 0; fi
    val=\$(extract_yaml_value "\$key" "inventory/group_vars/all.yaml")
    if [[ -n "\$val" ]]; then echo "\$val"; return 0; fi
    val=\$(grep -r "^\${key}:" inventory/group_vars/ 2>/dev/null | head -n 1 | sed -E "s/^.*\${key}:[[:space:]]*[\"']?([^\"']*)[\"']?.*$/\1/")
    echo "\$val"
}

echo ""
echo "==============================================="
echo "🚀 CLUSTER INSTALLATION SUMMARY"
echo "==============================================="
echo -e "Cluster Name:\t\t\$(get_var_value 'cluster_name')"
echo -e "GCP Project ID:\t\t\${PROJECT_ID:-\$(get_var_value 'google_project_id')}"
echo -e "GCP Region:\t\t\${REGION:-\$(get_var_value 'google_region')}"
echo -e "Storage Provider:\t\$(get_var_value 'storage_provider')"
echo -e "Control Plane VIP:\t\$(get_var_value 'control_plane_vip')"
echo -e "Ingress VIP:\t\t\$(get_var_value 'ingress_vip')"
echo -e "LB Pool CIDR:\t\t\$(get_var_value 'load_balancer_pool_cidr')"
echo -e "Root Repo URL:\t\t\${ROOT_REPO_URL:-\$(get_var_value 'acm_root_repo')}"
echo -e "Root Repo Branch:\t\${ROOT_REPO_BRANCH:-\$(get_var_value 'root_repository_branch')}"
echo "==============================================="
echo ""
echo "INFO: Installation will proceed automatically in 5 seconds."
echo "      Press Ctrl+C to abort."
for i in {5..1}; do
    echo -ne "Starting in \$i...\033[0K\r"
    sleep 1
done
echo ""

pretty_print "Starting the installation"
```

- [ ] **Step 2: Clean up the orphaned `else` block**

Since we removed the `if [[ "${proceed}" =~ ^([yY][eE][sS]|[yY])$ ]]; then` wrapper, we must remove its matching `else` block at the very end of `install.sh`.

Find and remove this at the end of the file:
```bash
else
    echo "Aborting."
    exit 0
fi
```

- [ ] **Step 3: Run the script to verify the summary UI and timeout**

Run: `bash install.sh`
Expected: The script should check the environment variables (it will likely fail the checks unless you have `.envrc` setup, but if it passes, it should display the summary box and start the 5-second countdown). If it exits early due to missing prerequisites, ensure those aren't breaking. We can mock `.envrc` or bypass checks to test the UI if needed, but visually inspecting the code replacement is the primary step here.

- [ ] **Step 4: Commit**

```bash
git add install.sh
git commit -m "feat: enhance install script with summary and automated timeout"
```
