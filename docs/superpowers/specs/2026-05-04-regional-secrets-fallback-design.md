# Design Spec: Regional Secrets Fallback via Try-Fail-Try

## Status
Proposed

## Context
Google Cloud Organization Policies can prohibit the creation of global secrets in Google Secret Manager (GSM). When global secrets are prohibited, attempts to get, list, or describe them globally will fail unless the `--location` flag is specified (for regional secrets).

The `consumer-edge-core` project heavily relies on GSM for storing and retrieving configuration, credentials, and tokens. We need to adapt all GSM "getters" (e.g., `versions access`, `describe`, `list`, `versions list`) to handle this scenario gracefully.

## Architecture

We will implement an inline "try-fail-try" approach (Option B from brainstorming) across the codebase.

Whenever a `gcloud secrets` command is used to retrieve data, it will first attempt the global operation. If the global operation fails, it will attempt the identical operation appended with the `--location` flag.

### Ansible Roles Implementation
In Ansible, `shell` or `command` tasks that invoke `gcloud secrets` will be modified to use `||` logic.
The fallback region variable will be `{{ google_region }}`.

**Example Pattern:**
```yaml
# Before
cmd: gcloud secrets versions list {{ secret_name }} --filter="state=enabled" --format="value(name)" --project="{{ google_secret_project_id }}"

# After
cmd: >
  gcloud secrets versions list {{ secret_name }} --filter="state=enabled" --format="value(name)" --project="{{ google_secret_project_id }}" ||
  gcloud secrets versions list {{ secret_name }} --filter="state=enabled" --format="value(name)" --project="{{ google_secret_project_id }}" --location="{{ google_region }}"
```

### Bash Scripts Implementation
In Bash scripts (e.g., `scripts/instance-context.sh`, `scripts/cloud/gce-helper.vars`, etc.), the same inline `||` logic will be used.
The fallback region variable is usually `$reg` or `$REGION` depending on the script context.

**Example Pattern:**
```bash
# Before
local val=$(gcloud secrets versions access latest --secret="${secret_name}" --project="${p_id}" 2>/dev/null)

# After
local val=$(gcloud secrets versions access latest --secret="${secret_name}" --project="${p_id}" 2>/dev/null || gcloud secrets versions access latest --secret="${secret_name}" --project="${p_id}" --location="${reg}" 2>/dev/null)
```

## Affected Areas
- `roles/validate/tasks/main.yml`
- `roles/cleanup/tasks/main.yml`
- `roles/abm-software/tasks/csi-robin.yaml`
- `roles/download-ssh-key/tasks/main.yml`
- `roles/gcp-setup/tasks/sds-longhorn-gcp.yaml`
- `roles/gcp-setup/tasks/sds-gcp-setup.yaml`
- `roles/gcp-setup/tasks/gsa-key-setup.yml`
- `scripts/cloud/gce-init.sh`
- `scripts/cloud/gce-helper.vars`
- `scripts/post-provision/delete-abm-gsa-keys-gcp.sh`
- `scripts/instance-context.sh`

## Testing Strategy
- Ensure `yamllint` or Ansible syntax checks pass after modification.
- Test reading a known global secret.
- Test reading a known regional secret by artificially making the global command fail (or testing in an environment where Org Policies prohibit global secrets).
