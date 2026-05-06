# Design Doc: Instance Context Overhaul

**Date:** 2026-05-05  
**Topic:** Overhaul of `scripts/instance-context.sh` for better UX and secret management.

## 1. Overview
The `instance-context.sh` script is the primary tool for managing cluster deployment contexts. This overhaul introduces explicit creation and download commands, a robust secret management hierarchy, and interactive prompting for missing required secrets.

## 2. Core Architecture
The script will be refactored into a "Unified Action-First Orchestrator". It will determine a primary `ACTION` (CREATE, DOWNLOAD, OPEN, CLOSE, INGEST, SWITCH, or LIST) and route logic to specialized functions.

### 2.1 Action Dispatcher
- `-c [name]`: **CREATE** a new local context.
- `-d [name]`: **DOWNLOAD** a context config from GSM.
- `-o`: **OPEN** (Hydrate) the current context.
- `-x`: **CLOSE** (Dehydrate) the current context.
- `-i [folder]`: **INGEST** an existing folder to GSM.
- `[name]` (positional): **SWITCH** the active context symlink.
- `-l`: **LIST** available contexts.

## 3. Secret Management
A centralized `get_or_provide_secret` mechanism will be implemented to handle all sensitive data (SSH keys, GSA JSONs, SCM tokens).

### 3.1 Secret Source Priority (The "Secret Provider")
When a secret is needed for hydration (`-o`) or ingestion (`-i`):
1. **Local Override File:** `configs/context-[name]-secrets.yaml`.
2. **Google Secret Manager (GSM):** Checked via `gcloud secrets`.
3. **Interactive Prompt (Required Secrets Only):** If missing in both 1 and 2, and the secret is **required**.

### 3.2 Synchronization Logic
- If a secret is sourced from **Local Override** or **Prompt**:
    - Hydrate the local file in `build-artifacts-[name]/`.
    - **Upload** the value to GSM to ensure cloud synchronization.
- If a secret is sourced from **GSM**:
    - Hydrate the local file in `build-artifacts-[name]/`.
- **Optional Secrets:** (e.g., OIDC) will NOT trigger a prompt. If not found, they remain unset.

### 3.3 Prompting Workflow
1. Prompt user for value (masked input).
2. Prompt user to re-enter value for confirmation.
3. If they match, proceed. If not, restart prompt loop.

## 4. Specific Flag Implementations

### 4.1 Create (`-c [name]`)
Scaffolds a new `build-artifacts-[name]/` folder based on the following mapping:

| Template Source | Final Destination | Stored in GSM |
| --------------- | ----------------- | :-----------: |
| `build-artifacts-example/add-hosts-example` | `build-artifacts-[name]/add-hosts` | No |
| `build-artifacts-example/consumer-edge-machine` | `build-artifacts-[name]/consumer-edge-machine` | Yes |
| `build-artifacts-example/consumer-edge-machine.pub` | `build-artifacts-[name]/consumer-edge-machine.pub` | Yes |
| `templates/envrc-template.sh` | `build-artifacts-[name]/envrc` | Yes (vars) |
| `templates/instance-run-vars-template.yaml` | `build-artifacts-[name]/instance-run-vars.yaml` | Partial |
| `templates/inventory-physical-example.yaml` | `build-artifacts-[name]/inventory.yaml` | No |
| `templates/context-config-template.yaml` | `configs/[name]-context.yaml` | Yes |
| `build-artifacts-example/node-gsa.json` | `build-artifacts-[name]/node-gsa.json` | Yes |
| `build-artifacts-example/provisioning-gsa.json` | `build-artifacts-[name]/provisioning-gsa.json` | Yes |
| `build-artifacts-example/ssh-config` | `build-artifacts-[name]/ssh-config` | No |
| N/A | `build-artifacts-[name]/robin-install-5.4.8-313.tar` | No |

- Automatically generates `configs/[name]-context.yaml`.
- Offers to push the config YAML to GSM as `context-[name]`.

### 4.2 Download (`-d [name]`)
- Looks for secret `context-[name]` in GSM.
- Saves to `configs/[name]-context.yaml`.
- Errors if not found: "Context configuration not found in Google Secret Manager with [name] and [project_id]".

## 5. UI/UX Enhancements
- Interactive confirmation for creation.
- Masked secret input during prompts.
- Clear status messaging for hydration and sync operations.
- Support for `configs/context-[name]-secrets.yaml` as an optional local provisioning file.
