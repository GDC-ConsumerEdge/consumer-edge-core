# Design Spec: Instance Context Secrets Automation

**Date:** 2026-05-08
**Status:** Draft
**Topic:** Automating the creation of secrets configuration files in `instance-context.sh`.

## 1. Problem Statement
Currently, when a user creates a new instance context using `./scripts/instance-context.sh -c [name]`, the script creates a folder for the artifacts and a main configuration file in `configs/[name]-context.yaml`. However, it does not automatically create the corresponding secrets file (`configs/[name]-context-secrets.yaml`), forcing the user to manually copy the template. This is inconsistent with the automation goal and can lead to missing secrets files during context generation.

## 2. Success Criteria
- Running `./scripts/instance-context.sh -c [name]` automatically creates both:
    - `configs/[name]-context.yaml`
    - `configs/[name]-context-secrets.yaml`
- The secrets file is a verbatim copy of `templates/context-config-secrets-template.yaml`.
- The user is notified of the creation of both files in the command output.
- The "Next Steps" guidance includes editing both files.

## 3. Proposed Changes

### `scripts/instance-context.sh`
Modify the `create_context` function:

1.  **Variable Declaration:** Add `local secrets_yaml="configs/${name}-context-secrets.yaml"` to the local variables in `create_context`.
2.  **Scaffolding:** Add a `cp` command to copy the template:
    ```bash
    cp "templates/context-config-secrets-template.yaml" "$secrets_yaml"
    ```
3.  **User Output:**
    - Update the summary printout to include the Secrets file path.
    - Update the "Next Steps" to mention both configuration files.

## 4. Implementation Details
The implementation will be surgical, focusing only on the `create_context` function in `scripts/instance-context.sh`. No other functions or logic (like `generate_context` or `hydrate_context`) need modification as they already handle the existence of secrets files if present.

## 5. Testing Plan
1.  **Reproduction/Verification:**
    - Run `./scripts/instance-context.sh -c test-auto-secrets`.
    - Verify that `configs/test-auto-secrets-context.yaml` AND `configs/test-auto-secrets-context-secrets.yaml` are created.
    - Verify that the output prints both file paths.
    - Verify that the "Next Steps" instructions are correct.
2.  **Cleanup:** Remove the created test files and directory.
