# How-To: Managing GDC Instance Contexts

## Overview
An **Instance Context** is a dedicated workspace containing the configuration, networking, and security keys for a specific GDC (Google Distributed Cloud) cluster. 

To keep our workstations secure, we use a **"Hydration" (Open/Close)** model:
*   **Closed (Dehydrated)**: Only public configuration is on disk. All passwords, tokens, and SSH keys are deleted.
*   **Open (Hydrated)**: Sensitive secrets are downloaded from Google Cloud Secret Manager (GSM) for active work.

All management is done via the helper script: `./scripts/instance-context.sh`

---

## 🚀 Quick Start: Create a New Context
Use this process when you need to set up a brand new cluster from scratch.

### 1. Prepare your Configuration
Create a file named `my-cluster.yaml` (you can copy the template from `templates/context-config-template.yaml`). 

```yaml
context_name: "denver-office"      # Name of the local folder
cluster_name: "gdc-denver-01"     # Human name of the cluster
project_id: "my-gcp-project-id"   # The GCP Project where secrets live
region: "us-central1"
zone: "us-central1-a"
control_plane_vip: "192.168.1.100"
ingress_vip: "192.168.1.101"
load_balancer_pool_cidr: "192.168.1.102-192.168.1.110"
nodes:
  - name: "node-1"
    ip: "192.168.1.10"
  - name: "node-2"
    ip: "192.168.1.11"
```

### 2. Generate the Context
Run the generate command:
```bash
./scripts/instance-context.sh -g my-cluster.yaml
```
**What this does:** 
- Creates the folder `build-artifacts-denver-office`.
- Generates a new SSH key pair.
- **Automatically uploads** the SSH keys to GSM in your GCP project.
- Leaves the folder in a **Closed** state (secrets wiped) for safety.

### 3. Add Manual Secrets to GSM
The script cannot create your Service Account keys or Git tokens. You must manually add these to GSM in your GCP project following this naming convention:
*   `gdc-denver-01-prov-gsa` (Upload your `provisioning-gsa.json` file)
*   `gdc-denver-01-scm-token` (The Git Personal Access Token string)

---

## 🔓 Working with Contexts: Open & Close

### Open a Context (Hydrate)
When you are ready to provision or update a cluster, you must "Open" the context to download the secrets.
```bash
# Open the currently active context
./scripts/instance-context.sh -o

# OR: Switch to 'denver-office' AND open it at the same time
./scripts/instance-context.sh -o denver-office
```

### Close a Context (Dehydrate)
**Always do this when you finish your work or leave your desk.** This wipes the private keys and tokens from your hard drive.
```bash
# Close the active context
./scripts/instance-context.sh -x
```

---

## 🔄 Switching Between Clusters
If you are working on `Cluster A` and need to move to `Cluster B`, use the switch command.

**Secure Switch (Recommended):**
This wipes the secrets from your current cluster before moving to the next one.
```bash
./scripts/instance-context.sh -x denver-office
```

**Standard Switch:**
Just changes the pointer without wiping secrets.
```bash
./scripts/instance-context.sh denver-office
```

---

## 📥 Import: Converting Old Folders
If you have an old `build-artifacts-xyz` folder that wasn't created with this new system, you can "Ingest" it. 

```bash
./scripts/instance-context.sh -i folder-name
```
**What this does:**
1. Reads the `envrc` inside that folder to find the Project ID.
2. Scans for existing SSH keys and Service Account JSONs.
3. **Uploads everything found** to GSM.
4. **Dehydrates** the folder (secures it).

---

## 📝 Updating Configuration
If you need to change a non-sensitive value (like a Node IP or a VIP):
1. Navigate to the context folder: `cd build-artifacts-your-name`.
2. Manually edit `inventory.yaml` or `envrc`.
3. If the change is sensitive (like a new Token), update the value in the **GCP Secret Manager Console** directly.

---

## 🗑️ Deleting a Context
To completely remove a context:

1. **Delete the Local Folder**:
   ```bash
   rm -rf build-artifacts-denver-office
   ```
2. **Delete the GSM Secrets**:
   Go to the GCP Console -> Secret Manager and delete the secrets starting with `gdc-denver-01-*`. *Note: The script does not delete GSM secrets to prevent accidental data loss.*

---

## 🛠️ Troubleshooting
*   **"Permission Denied"**: Run `gcloud auth application-default login` to ensure you are authenticated to GCP.
*   **"yq not found"**: This script requires the `yq` tool. Install it via `sudo apt install yq` or your package manager.
*   **"Secret not found"**: Double-check that your GSM secret name matches the `gdc-{cluster_name}-{type}` convention exactly.
