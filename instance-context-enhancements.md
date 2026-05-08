# Implementation Plan: Instance Context Enhancements

## Goal
Enhance `instance-context.sh` to support name-based generation and add a comprehensive test suite in `tests/instance-context/`.

## Tasks

### Phase 1: Script Enhancements
- [x] **Task 1: Update `instance-context.sh` usage and argument parsing**
    - Modify `usage` function to show `-g name`.
    - Update `while` loop to capture `CONTEXT_NAME` for `-g`.
    - Derive `YAML_FILE` from `CONTEXT_NAME`.
    - Verify: `./scripts/instance-context.sh -h` shows `-g name`.
- [x] **Task 2: Refactor `generate_context` function**
    - Update function signature to accept `context_name`.
    - Implement the existence check for `configs/${context_name}-context.yaml`.
    - Remove interactive "y/N" prompt at step 3.
    - Verify: `./scripts/instance-context.sh -g non-existent` fails with the specific error message.
- [x] **Task 3: Audit `create_context` function**
    - Ensure it uses `@templates/**` and handles GSM existence check correctly.
    - Verify: Code review of the function.

### Phase 2: Test Suite Development
- [x] **Task 4: Scaffold Test Directory and Runner**
    - Create `tests/instance-context/` directory.
    - Create `tests/instance-context/run-tests.sh` with state isolation logic.
    - Verify: `ls tests/instance-context/run-tests.sh` exists.
- [x] **Task 5: Implement Generation Test**
    - Create `tests/instance-context/test-generate.sh`.
    - Implement AAA pattern to verify `envrc`, `inventory.yaml`, and `instance-run-vars.yaml`.
    - Verify: `tests/instance-context/run-tests.sh` runs and fails if generation is broken.
- [x] **Task 6: Implement Creation Test**
    - Create `tests/instance-context/test-create.sh`.
    - Mock `gcloud` to verify secret creation.
    - Verify: `tests/instance-context/run-tests.sh` runs and passes for creation.

### Phase 3: Final Verification
- [x] **Task 7: Run Full Test Suite**
    - Execute all tests in the new suite.
    - Verify: All tests pass.

## Done When
- [x] `instance-context.sh -g <name>` uses the new derivation logic.
- [x] `create_context` is verified to use templates.
- [x] New test suite in `tests/instance-context/` is complete and passing.
