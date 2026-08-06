# GCP Infrastructure Decoupling and Verification Design

**Date:** 2026-05-04
**Status:** Draft
**Goal:** Decouple GCP infrastructure provisioning from software installation, enhance pre-flight verification, and provide a reference Terraform alternative.

## 1. Overview
The current codebase interleaves GCP infrastructure mutation (creating service accounts, secrets, and buckets) with the software installation process. This design centralizes these mutations into a dedicated "cloud-first" flow, adds rigorous verification to ensure required resources exist before installation, and provides a Terraform project as an alternative to `gcloud`-based provisioning.

## 2. Components

### A. New Playbook: `all-gcp-provision.yml`
- **Target:** `localhost`
- **Role:** Calls the `gcp-setup` role.
- **Purpose:** The primary entry point for provisioning all cloud-based dependencies using `gcloud`. This allows users to set up their GCP project in a single step before running the software installation.

### B. Consolidated Role: `roles/gcp-setup`
- **Consolidation:** Move all tasks tagged with `gcloud-mutate` from `roles/abm-software` and other roles into `roles/gcp-setup`.
- **Responsibilities:**
    - **APIs:** Enable required GCP Services (Compute, IAM, Secret Manager, Container Hub).
    - **IAM:** Create/Enable GSAs (provisioning, node, etc.) and assign IAM roles.
    - **Secrets:** 
        - Provision `google_secret_manager_secret` for GSA keys, SDS licenses, and Git credentials.
        - Generate and upload JSON keys to Secret Manager (ensuring local cleanup).
    - **Storage:** Create GCS buckets for cluster snapshots, SDS backups, and distributed locks.
    - **Specialized:** Create HMAC keys for SDS backends (e.g., Longhorn).

### C. Enhanced Verification: `roles/validate`
- **Target:** All hosts (or delegated to localhost for GCP checks).
- **New Checks:**
    - **API Status:** Verify required services are enabled.
    - **IAM Status:** Verify GSAs exist and have expected roles.
    - **Secret Status:** Verify required secrets (and active versions) exist.
    - **Storage Status:** Verify GCS buckets exist and the caller has `storage.buckets.get` permissions.
- **Playbook Integration:** Ensure `all-verify.yml` runs these checks.

### D. Alternative Provisioning: `terraform/`
- **Structure:** Single root module (`main.tf`, `variables.tf`, `outputs.tf`).
- **Scope:** 
    - Enable Project Services.
    - Create Service Accounts and IAM Policy Bindings.
    - Create Secret Manager Secrets (Placeholder versions for keys).
    - Create Storage Buckets.
    - Create Storage HMAC keys.
- **Note:** This is a reference solution and may not cover every edge case handled by the `gcloud` scripts (e.g., specific error handling for max HMAC keys).

## 3. Data Flow & Variables
All components will use a consistent variable naming convention to ensure interoperability:
- `google_project_id`
- `google_region` / `google_zone`
- `service_accounts` (list of objects with name, description, roles)
- `snapshot_gcs_bucket_base`
- `storage_provider_gcs_bucket_name`

## 4. Implementation Strategy
1.  **Refactor `gcp-setup`**: Move tasks from `abm-software` into `gcp-setup`. Clean up `abm-software` tasks that are now redundant.
2.  **Create `all-gcp-provision.yml`**: Define the playbook and test against a clean project.
3.  **Update `validate`**: Add `gcloud` check tasks to `roles/validate/tasks/main.yml` (or a sub-task file).
4.  **Scaffold Terraform**: Create the `terraform/` directory and implement resources based on the identified mutations.

## 5. Testing & Success Criteria
- `all-gcp-provision.yml` successfully provisions all resources in a fresh GCP project.
- `all-verify.yml` passes if resources exist (via `gcloud` or Terraform) and fails with clear error messages if any are missing.
- `roles/abm-software` no longer contains tasks that modify GCP resources (no `gcloud-mutate` tags).
- Terraform project runs `plan` and `apply` without errors, matching the state expected by Ansible.
