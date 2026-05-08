# Design: Secrets File Workflow

**Date:** 2026-05-07
**Status:** Approved
**Topic:** Generating context using a companion secrets file.

## 1. Overview
This design outlines a new feature for `instance-context.sh`: the ability to provide a companion `configs/[name]-context-secrets.yaml` file during the generation phase. This file acts as a source of truth for secrets, pushing them to Google Secret Manager (GSM) and avoiding interactive prompts.

## 2. Script Enhancements (`scripts/instance-context.sh`)

### 2.1 The `process_secrets_file` Function (Pre-Processing)
- A new function will be added. 
- During `generate_context`, if `configs/[ctx_name]-context-secrets.yaml` exists, this function will be called *before* the main secret validation block.
- **Logic:**
  1. Use `yq` to parse the 8 known secrets: `scm_user`, `scm_token`, `prov_gsa`, `node_gsa`, `ssh_pub_key`, `ssh_key`, `oidc_id`, `oidc_secret`.
  2. If a value is present (not null/empty), it pushes the value directly to GSM via `gsm_put`.
  3. `gsm_put` handles adding new versions, ensuring the file's contents overwrite existing GSM state.
  4. If a value is missing or empty in the file, it is skipped.

### 2.2 Fail Fast Validation
- The current validation logic prompts the user if required SCM secrets (`scm_user`, `scm_token`) are missing.
- **Change:** If the script is running with a secrets file (or generally, to adhere to the new rule), it should fail fast rather than prompt. If these secrets are missing after the pre-processing phase, the script will log an error and `exit 1`.
- *Note:* SSH keys are auto-generated if missing, and GSA keys have local-file fallbacks. These non-interactive fallbacks will remain, but the script must not pause for user input.

## 3. Test Suite (`tests/instance-context/`)

### 3.1 `test-generate-secrets.sh`
- Follows the AAA pattern and State Isolation.
- **Arrange:** 
  - Create a mock `configs/test-sec-context.yaml`.
  - Create a mock `configs/test-sec-context-secrets.yaml` populated with dummy values for all 8 secrets.
- **Act:** 
  - Run `./scripts/instance-context.sh -g test-sec`.
  - Implement a `gcloud` mock that intercepts `secrets versions add` and `secrets create` and logs the actions.
- **Assert:**
  - Verify that the `gcloud` mock was called 8 times to push the 8 secrets from the file.
  - Verify that no interactive prompts were triggered.
  - Verify the target directory and files are created.

## 4. Success Criteria
- The script successfully reads the secrets file and pushes the values to GSM.
- The script fails immediately if required secrets are completely absent.
- The new test case passes consistently.