# How-To: Managing GDC Instance Contexts

## Overview
An **Instance Context** is a dedicated workspace containing the configuration, networking, and security keys for a specific GDC (Google Distributed Cloud) cluster.

To keep our workstations secure, we use a **"Hydration" (Open/Close)** model:
*   **Closed (Dehydrated)**: Only public configuration is on disk. All passwords, tokens, and SSH keys are deleted.
*   **Open (Hydrated)**: Sensitive secrets are downloaded from Google Cloud Secret Manager (GSM) for active work.

All management is done via the helper script: `./scripts/instance-context.sh`

---

## 🚀 Quick Start: End-to-End Workflow

Use this process when you are starting fresh and do not have a context folder locally.

### Step 1: Create a New Context
Use the `-c` flag to scaffold a new context named `my-cluster`:
```bash
./scripts/instance-context.sh -c my-cluster
```
*This creates the `build-artifacts-my-cluster` folder and `configs/my-cluster-context.yaml`. It is linked as your active context.*

### Step 2: Edit Configuration
Navigate to the new folder and update your IPs, nodes, and cluster name:
```bash
cd build-artifacts-my-cluster
# Edit inventory.yaml, instance-run-vars.yaml, envrc, etc.
```

### Step 3: Open (Hydrate) the Context
Before you can run Ansible, you need secrets (SSH keys, tokens). Open the context:
```bash
../scripts/instance-context.sh -o
```
*The script will check Google Secret Manager. If secrets are missing, it will prompt you interactively to provide them, save them to GSM for next time, and hydrate your local folder.*

### Step 4: Do Your Work
Run your provisioning or deployment scripts.

### Step 5: Close (Dehydrate) the Context
When finished, wipe the sensitive data from your local machine:
```bash
../scripts/instance-context.sh -x
```
*Your secrets are safely stored in GSM, and your local folder is secured.*

---

## 🚦 Context Lifecycle & States

An instance context transitions through several states during its lifecycle. Understanding these states is critical for secure operations.

| State | Description | Security Posture | Action to Transition |
| :--- | :--- | :--- | :--- |
| **Not Created** | The folder (`build-artifacts-<name>`) does not exist on disk. | N/A | `./scripts/instance-context.sh -c <name>` |
| **Created / Closed** <br>*(Dehydrated)* | The folder exists with basic configuration (`inventory.yaml`, etc.), but **all secrets are removed**. `envrc` secrets are scrubbed. | **Secure**. Safe to leave unattended. | `./scripts/instance-context.sh -o` |
| **Opened** <br>*(Hydrated)* | The folder is active. Sensitive secrets (SSH keys, GSA JSONs, SCM Tokens) have been downloaded from GSM or local overrides. | **Vulnerable**. Do not leave workstation unattended. | `./scripts/instance-context.sh -x` |

---

## 📥 Downloading an Existing Context

If a context configuration already exists in Google Secret Manager (GSM) but is not on your local machine, use the Download command.

1.  **Download the Configuration YAML from GSM**:
    ```bash
    ./scripts/instance-context.sh -d my-cluster
    ```
    *This looks for a secret named `context-my-cluster` in GSM and saves it to `configs/my-cluster-context.yaml`.*

2.  **Generate the Local Folder**:
    ```bash
    ./scripts/instance-context.sh -g configs/my-cluster-context.yaml
    ```
    *This creates `build-artifacts-my-cluster` based on the downloaded YAML and leaves it in a Closed state.*

3. **Open the context to get secrets**:
    ```bash
    ./scripts/instance-context.sh -o my-cluster
    ```

---

## 🔑 Secret Management & Overrides

When you Open (`-o`) a context, the script looks for secrets in this specific order:

1.  **Local Override File:** `configs/context-<name>-secrets.yaml`
2.  **Google Secret Manager (GSM)**
3.  **Interactive Prompt:** (Only for required secrets)

### Providing Secrets via Local Override

If you don't want to use the interactive prompts, or need to override what is in GSM, you can create a secrets YAML file: `configs/context-<name>-secrets.yaml`.

**Example `configs/context-my-cluster-secrets.yaml`:**
```yaml
scm_user: "my-username"
scm_token: "glpat-xxxxxxxxxxxxxxxxxxxx"
prov_gsa: |
  {
    "type": "service_account",
    "project_id": "my-project",
    ...
  }
```

*Note: Any secret found in this override file will be hydrated locally **AND uploaded to GSM** to ensure the cloud state stays synchronized.*

---

## 🔍 Inspecting Contexts

### List Available Contexts
To see all local context folders:
```bash
./scripts/instance-context.sh -l
```
The active context will be marked with a `*`.

### View Current Context Details
To see the active project, region, and cluster configuration:
```bash
./scripts/instance-context.sh -c
```

---

## 🔄 Switching Between Clusters
If you are working on `Cluster A` and need to move to `Cluster B`, use the switch command.

**Secure Switch (Recommended):**
Close your current context before switching.
```bash
./scripts/instance-context.sh -x
./scripts/instance-context.sh my-other-cluster
```

**Implicit Switch:**
You can just pass the name of an existing folder to switch the active symlink.
```bash
./scripts/instance-context.sh my-other-cluster
```

---

## 📥 Ingest: Converting Old Folders
If you have an old `build-artifacts-xyz` folder that wasn't created with the new YAML/Create system, you can "Ingest" it into GSM.

```bash
./scripts/instance-context.sh -i xyz
```
**What this does:**
1. Reads the `envrc` inside that folder to find the Project ID and Cluster Name.
2. Scans for existing SSH keys and Service Account JSONs locally.
3. **Uploads everything found** to GSM.
4. Generates a backup configuration YAML in `configs/`.
5. **Dehydrates** the folder (secures it).

---

## 🗑️ Deleting a Context
To completely remove a context:

1. **Delete the Local Folder**:
   ```bash
   rm -rf build-artifacts-denver-office
   ```
2. **Delete the GSM Secrets**:
   Go to the GCP Console -> Secret Manager and delete the secrets starting with `gdc-{cluster_name}-*`. *Note: The script does not delete GSM secrets to prevent accidental data loss.*