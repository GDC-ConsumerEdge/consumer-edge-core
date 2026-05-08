# Implementation Plan: Secrets File Workflow

## Goal
Implement a companion secrets file workflow in `instance-context.sh` that pre-processes secrets into GSM and fails fast if required secrets are missing, supported by a new mock-heavy test.

## Tasks

### Phase 1: Pre-Processing Logic
- [x] **Task 1: Create `process_secrets_file` function**
    - Define the function in `scripts/instance-context.sh`.
    - Iterate over the 8 known secret keys using `yq`.
    - Push valid, non-null values to GSM using `gsm_put`.
    - Verify: Code review of the function.
- [x] **Task 2: Integrate into `generate_context`**
    - Check for `configs/${ctx_name}-context-secrets.yaml` early in `generate_context`.
    - If it exists, call `process_secrets_file`.
    - Verify: Code review of the placement.

### Phase 2: Fail Fast Validation
- [x] **Task 3: Refactor SCM validation**
    - Locate the SCM validation block in `generate_context`.
    - Remove interactive `read` prompts for `scm_user` and `scm_token`.
    - Replace with `exit 1` and a clear error message.
    - Verify: Code review.
- [x] **Task 4: Refactor GSA validation**
    - Locate the `ensure_gsa_key` function.
    - Remove the interactive prompt (`read answer`, `read sa_email`).
    - Replace with a "fail fast" error message and `exit 1`.
    - Verify: Code review.

### Phase 3: Testing
- [x] **Task 5: Implement `test-generate-secrets.sh`**
    - Create the script in `tests/instance-context/`.
    - Scaffold YAML and Secrets files using templates.
    - Implement a `gcloud` mock that tracks calls to a log file.
    - Assert that 8 distinct secrets were pushed to GSM.
    - Verify: `bash tests/instance-context/run-tests.sh` runs the new test successfully.

## Done When
- [x] A secrets file can successfully populate GSM without prompts.
- [x] Missing secrets trigger a fast failure instead of hanging the script.
- [x] The `test-generate-secrets.sh` test passes.
