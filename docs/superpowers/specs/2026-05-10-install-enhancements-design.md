# Design Specification: Enhanced Cluster Installation Experience

## 1. Context and Goals
The current `install.sh` script is the primary entry point for cluster installations. While it performs necessary environment checks, it lacks a comprehensive summary of the configuration being deployed and requires multiple manual "Y/N" confirmations, slowing down automated or repetitive deployments.

The goal is to:
1. Provide a clear, pre-flight summary of critical cluster details (Cluster Name, VIPs, Repos, Storage Provider, etc.).
2. Remove manual "Y/N" confirmation prompts.
3. Replace confirmations with an automated "timeout" mechanism (e.g., 5 seconds) that proceeds automatically unless interrupted.

## 2. Architecture & Approach
We will implement **Option A** (Enhanced CLI Summary + Automated Handoff).

*   **Extraction:** We will use standard bash utilities (`grep`, `sed`, `awk`) within `install.sh` to extract necessary variables. Since `install.sh` runs before the Ansible environment is fully available, we will extract values from:
    *   Sourced environment variables (from `.envrc`).
    *   `inventory/group_vars/all.yaml` (for global defaults).
    *   `inventory/group_vars/cloud_vxlanid_*.yaml` or similar specific cluster configs if a specific inventory file is referenced (we'll prioritize `all.yaml` and `.envrc` as primary sources, and attempt to grep specific variables from the general `inventory/` directory if needed).
*   **Presentation:** We will create a `print_summary` function to display a formatted table/box of the extracted values.
*   **Automation:** We will use the `read -t 5` command to implement a 5-second countdown timer.

## 3. Data Extraction Strategy

We need to gather the following fields:
*   `cluster_name`
*   `root_repo_url`
*   `root_repo_branch`
*   `project_id`
*   `region`
*   `storage_provider`
*   `control_plane_vip`
*   `ingress_vip`
*   `load_balancer_pool_cidr`

**Extraction Logic:**
1.  **Environment Variables:** Check for variables like `$PROJECT_ID`, `$REGION`, `$ROOT_REPO_URL` which might already be set in the environment.
2.  **YAML Grepping:** For variables strictly in YAML (like VIPs), we will use a helper function:
    ```bash
    function extract_yaml_value() {
        local key=$1
        local file=$2
        grep "^${key}:" "$file" | sed -E "s/^${key}:[[:space:]]*[\"']?([^\"']*)[\"']?.*$/\1/"
    }
    ```
    *Note: If a variable is in a specific cluster file (like `cloud_vxlanid_40.yaml`), we will need to search the `inventory/group_vars/` directory for it. If `instance-run-vars.yaml` exists, it should take precedence.*

## 4. UI / Summary Block Design

The summary will be printed just before the final execution phase. It will look similar to this:

```text
===============================================
🚀 CLUSTER INSTALLATION SUMMARY
===============================================
Cluster Name:        gdc-demo
GCP Project ID:      my-gcp-project
GCP Region:          us-central1
Storage Provider:    robin
Control Plane VIP:   10.200.0.49
Ingress VIP:         10.200.0.50
LB Pool CIDR:        10.200.0.50-10.200.0.70
Root Repo URL:       https://gitlab.com/...
Root Repo Branch:    main
===============================================
```

## 5. Automated Handoff

The existing manual prompts:
```bash
read -p "Do you accept the responsiblity... (y/N):" proceed
read -p "Check the values above... (y/N): " proceed
```
Will be replaced with:
```bash
echo ""
echo "INFO: Installation will proceed automatically in 5 seconds."
echo "      Press Ctrl+C to abort."
for i in {5..1}; do
    echo -ne "Starting in $i...\033[0K\r"
    sleep 1
done
echo ""
```
*Note: We will remove the OSS responsibility prompt as it adds an unnecessary blocker; if required by policy, we can print it as a warning statement instead of a prompt.*