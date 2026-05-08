# Design: Instance Context Enhancements

**Date:** 2026-05-07
**Status:** Approved
**Topic:** Enhancing `instance-context.sh` and adding a robust test suite.

## 1. Overview
This design outlines enhancements to the `instance-context.sh` script to simplify the context generation process and ensures that the creation phase correctly utilizes templates. It also defines a new, comprehensive test suite to verify these behaviors.

## 2. Script Enhancements (`scripts/instance-context.sh`)

### 2.1 Update "Generate" Phase
- **Change:** The `-g` flag will now accept a **context name** instead of a direct file path.
- **Logic:**
    1.  Capture the `CONTEXT_NAME` from the `-g` flag.
    2.  Derive the `YAML_FILE` path: `configs/${CONTEXT_NAME}-context.yaml`.
    3.  Check if the file exists. If it **DOES NOT** exist, fail with the message: `Error: File path 'configs/${CONTEXT_NAME}-context.yaml' does not exist and cannot generate a new context folder.`
    4.  Update the `generate_context` function to take the `CONTEXT_NAME` as an argument and use the derived path.
- **Goal:** Improve UX by abstracting the configuration file location.

### 2.2 Ensure "Create" Phase Correctness
- **Validation:** Ensure that the `create_context` function correctly uses `@templates/**` files when constructing a new context.
- **GSM Check:** Confirm that it correctly identifies if a GSM context-file exists and advises using the `-d` (download) flag if so.

## 3. Test Suite (`tests/instance-context/`)

### 3.1 Principles
- **AAA Pattern:** Arrange, Act, Assert.
- **State Isolation:** Each test will run in a clean, temporary environment to avoid side effects.
- **Mocking:** Mock `gcloud` and Secret Manager interactions to keep tests functional and fast (avoiding real GCP calls).
- **Single Purpose:** One test = One user action + One outcome.

### 3.2 Test Cases

#### Generation Test
1.  **Arrange:** Create a temporary `configs/test-cluster-context.yaml` using `templates/context-config-template.yaml`.
2.  **Act:** Run `./scripts/instance-context.sh -g test-cluster`.
3.  **Assert:**
    -   Directory `build-artifacts-test-cluster` exists.
    -   `ssh-config`, `instance-run-vars.yaml`, `inventory.yaml`, `envrc` exist in the folder.
    -   `envrc` contains correct `REGION`, `SCM_TOKEN_USER`, and `SCM_TOKEN_TOKEN`.
    -   `inventory.yaml` has the correct number of nodes, names, and IPs.
    -   `instance-run-vars.yaml` has `storage_provider: robin` and a valid `abm_version`.

#### Creation Test
1.  **Arrange:** Ensure no existing context or GSM secret.
2.  **Act:** Run `./scripts/instance-context.sh -c test-create`.
3.  **Assert:**
    -   `configs/test-create-context.yaml` is created from template.
    -   `build-artifacts-test-create/` contains files derived from templates.
    -   (Mocked) Secret `context-test-create` is created in GSM.

## 4. Success Criteria
- `instance-context.sh -g <name>` works as expected and fails gracefully if the config is missing.
- `instance-context.sh -c <name>` scaffolds a new context correctly from templates.
- All tests in the new test suite pass consistently.
