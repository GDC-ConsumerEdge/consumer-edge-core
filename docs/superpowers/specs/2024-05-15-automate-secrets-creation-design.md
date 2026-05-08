# Design Document: Automate Secrets Configuration File Creation

**Date:** 2024-05-15
**Topic:** Automating the creation of a secrets configuration file when a new context is created in `instance-context.sh`.

## 1. Overview
The current `instance-context.sh` script creates a context configuration file when a new context is created, but it does not create the companion secrets file. This design automates the creation of `configs/<name>-context-secrets.yaml` from a template, improving the onboarding experience for new contexts.

## 2. Proposed Changes

### 2.1 `scripts/instance-context.sh`
Modify the `create_context` function:
- Declare `secrets_yaml` variable.
- Copy `templates/context-config-secrets-template.yaml` to the new secrets file path.
- Update the final UX output to include the secrets file path and instructions to edit it.

## 3. Detailed Design

### 3.1 `create_context` Modification
```bash
function create_context() {
    local name="$1"
    # ...
    local target="build-artifacts-${name}"
    local config_yaml="configs/${name}-context.yaml"
    local secrets_yaml="configs/${name}-context-secrets.yaml" # Added
    # ...
    # 2. Scaffolding
    # ...
    cp "templates/context-config-template.yaml" "$config_yaml"
    cp "templates/context-config-secrets-template.yaml" "$secrets_yaml" # Added
    # ...
    # 5. Final UX: Link as active
    # ...
    pretty_print "Config: ${config_yaml}"
    pretty_print "Secrets: ${secrets_yaml}" # Added
    pretty_print "\nNext Steps:" "INFO"
    pretty_print "1. Edit ${config_yaml} and ${secrets_yaml} to match your environment." # Updated
    # ...
}
```

## 4. Verification Plan

### 4.1 Automated Verification
- Run `bash -n scripts/instance-context.sh` to check for syntax errors.

### 4.2 Manual Verification
1. Create a test context: `./scripts/instance-context.sh -c test-auto-secrets`
2. Confirm the following files exist:
   - `build-artifacts-test-auto-secrets/` (directory)
   - `configs/test-auto-secrets-context.yaml`
   - `configs/test-auto-secrets-context-secrets.yaml`
3. Confirm the console output includes:
   - `Secrets: configs/test-auto-secrets-context-secrets.yaml`
   - `1. Edit configs/test-auto-secrets-context.yaml and configs/test-auto-secrets-context-secrets.yaml to match your environment.`
4. Cleanup:
   - `rm -rf build-artifacts-test-auto-secrets`
   - `rm configs/test-auto-secrets-context.yaml`
   - `rm configs/test-auto-secrets-context-secrets.yaml`
   - `rm build-artifacts` (if it points to the test context)
