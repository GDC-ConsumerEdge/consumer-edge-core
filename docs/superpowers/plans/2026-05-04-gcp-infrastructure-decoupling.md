# GCP Infrastructure Decoupling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Decouple GCP infrastructure provisioning from software installation by centralizing mutations in `gcp-setup`, adding verification to `validate`, and providing a Terraform alternative.

**Architecture:** Consolidates all `gcloud-mutate` tasks into a single role and playbook. Adds a pre-flight verification layer in the `validate` role to check GCP resources. Scaffolds a reference Terraform project for resource parity.

**Tech Stack:** Ansible, gcloud CLI, Terraform, Bash.

---

### Task 1: Consolidate GCP Mutation Tasks

**Files:**
- Modify: `roles/abm-software/tasks/csi-robin.yaml`
- Modify: `roles/gcp-setup/tasks/sds-gcp-setup.yaml`

- [ ] **Step 1: Move Robin license task to gcp-setup**
  - Move the "Create Robin GCP Secret" task (around L61-75) from `roles/abm-software/tasks/csi-robin.yaml` to `roles/gcp-setup/tasks/sds-gcp-setup.yaml`.

- [ ] **Step 2: Clean up original files**
  - Remove the moved task from `roles/abm-software/tasks/csi-robin.yaml`.
  - Remove any other tasks in `roles/abm-software/tasks/*.yaml` tagged with `gcloud-mutate` (none found in audit besides Robin).

- [ ] **Step 3: Commit consolidation**
  ```bash
  git add roles/abm-software/tasks/csi-robin.yaml roles/gcp-setup/tasks/sds-gcp-setup.yaml
  git commit -m "refactor: consolidate gcloud-mutate tasks into gcp-setup role"
  ```

---

### Task 2: Create GCP Provisioning Playbook

**Files:**
- Create: `all-gcp-provision.yml`

- [ ] **Step 1: Define the new playbook**
  - Create `all-gcp-provision.yml` targeting `localhost` and calling the `gcp-setup` role.
  ```yaml
  ---
  - hosts: localhost
    connection: local
    gather_facts: false
    roles:
      - gcp-setup
    vars:
      primary_cluster_machine: true
  ```

- [ ] **Step 2: Commit playbook**
  ```bash
  git add all-gcp-provision.yml
  git commit -m "feat: add all-gcp-provision.yml playbook for cloud-only setup"
  ```

---

### Task 3: Enhance Pre-flight Verification

**Files:**
- Create: `roles/validate/tasks/gcp-checks.yml`
- Modify: `roles/validate/tasks/main.yml`

- [ ] **Step 1: Implement GCP check tasks**
  - Create `roles/validate/tasks/gcp-checks.yml` with tasks to verify:
    - Project services enabled.
    - GSAs exist.
    - GSM Secrets (and latest versions) exist.
    - GCS Buckets exist.
  - Use `gcloud` commands with `delegate_to: localhost` and `run_once: true`.

- [ ] **Step 2: Integrate into validate role**
  - Add `import_tasks: gcp-checks.yml` to `roles/validate/tasks/main.yml`.

- [ ] **Step 3: Commit verification**
  ```bash
  git add roles/validate/tasks/gcp-checks.yml roles/validate/tasks/main.yml
  git commit -m "feat: add GCP resource verification to validate role"
  ```

---

### Task 4: Scaffold Reference Terraform Project

**Files:**
- Create: `terraform/main.tf`
- Create: `terraform/variables.tf`
- Create: `terraform/outputs.tf`

- [ ] **Step 1: Define variables**
  - Map Ansible variables (`google_project_id`, `service_accounts`, etc.) to Terraform variables.

- [ ] **Step 2: Implement resources in main.tf**
  - `google_project_service`
  - `google_service_account`
  - `google_project_iam_member`
  - `google_secret_manager_secret`
  - `google_storage_bucket`

- [ ] **Step 3: Commit Terraform**
  ```bash
  git add terraform/
  git commit -m "feat: add reference terraform project for GCP infrastructure"
  ```

---

### Task 5: Final Validation

- [ ] **Step 1: Run verification**
  - Run `ansible-playbook all-verify.yml` and ensure it fails gracefully if GCP resources are missing, and passes when they exist.

- [ ] **Step 2: Verify gcloud-mutate isolation**
  - Grep for `gcloud-mutate` tags across `roles/` and ensure they only exist in `gcp-setup`.

- [ ] **Step 3: Final Commit**
  ```bash
  git commit --allow-empty -m "docs: complete GCP infrastructure decoupling implementation"
  ```
