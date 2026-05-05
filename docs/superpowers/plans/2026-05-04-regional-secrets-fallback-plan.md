# Regional Secrets Fallback Implementation Plan

## Goal
Implement a "try global, then try regional" fallback for all `gcloud secrets` read commands (getters) across Ansible roles and bash scripts to support environments where Org Policies prohibit global secrets.

## Tasks

- [ ] Task 1: Update Bash scripts in `scripts/cloud/`
  - Modify `scripts/cloud/gce-init.sh` and `scripts/cloud/gce-helper.vars`
  - Replace `gcloud secrets ...` with `gcloud secrets ... || gcloud secrets ... --location=${REGION}` (or equivalent context variable).
  - Verify: Run `bash -n scripts/cloud/gce-init.sh` and check syntax.

- [ ] Task 2: Update Bash scripts in `scripts/post-provision/` and `scripts/`
  - Modify `scripts/post-provision/delete-abm-gsa-keys-gcp.sh` and `scripts/instance-context.sh`
  - Replace `gcloud secrets ...` with `gcloud secrets ... || gcloud secrets ... --location=...`
  - Verify: Run `bash -n scripts/instance-context.sh`.

- [ ] Task 3: Update Ansible roles for cleanup and validation
  - Modify `roles/validate/tasks/main.yml`, `roles/cleanup/tasks/main.yml`, and `roles/download-ssh-key/tasks/main.yml`.
  - Replace `gcloud secrets ...` commands with inline fallback using `--location="{{ google_region }}"`.
  - Use `>` for multi-line strings in Ansible YAML to keep it readable.
  - Verify: Run `yamllint` on modified files.

- [ ] Task 4: Update Ansible roles for gcp-setup and abm-software
  - Modify `roles/gcp-setup/tasks/sds-longhorn-gcp.yaml`, `roles/gcp-setup/tasks/sds-gcp-setup.yaml`, `roles/gcp-setup/tasks/gsa-key-setup.yml`, and `roles/abm-software/tasks/csi-robin.yaml`.
  - Implement the inline fallback logic.
  - Verify: Run `yamllint` on modified files.

## Done When
- [ ] All instances of `gcloud secrets` read operations (list, describe, versions list, versions access) fallback to `--location` if the global command fails.
- [ ] Syntax checks pass for modified bash and YAML files.
