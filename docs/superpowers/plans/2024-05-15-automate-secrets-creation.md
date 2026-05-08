# Automate Secrets Creation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automatically create a companion secrets configuration file when a new context is created in `instance-context.sh`.

**Architecture:** Modify the `create_context` function in `scripts/instance-context.sh` to copy `templates/context-config-secrets-template.yaml` to `configs/<name>-context-secrets.yaml` and update the final UX messages.

**Tech Stack:** Bash

---

### Task 1: Modify `create_context` function

**Files:**
- Modify: `scripts/instance-context.sh`

- [ ] **Step 1: Declare secrets file variable**

In `scripts/instance-context.sh`, locate the `create_context` function (around line 1025). Add the `secrets_yaml` variable below `config_yaml`.

```bash
<<<<
    local target="build-artifacts-${name}"
    local config_yaml="configs/${name}-context.yaml"
====
    local target="build-artifacts-${name}"
    local config_yaml="configs/${name}-context.yaml"
    local secrets_yaml="configs/${name}-context-secrets.yaml"
>>>>
```

- [ ] **Step 2: Copy secrets template during scaffolding**

In the same function, under `# 2. Scaffolding` (around line 1045), add the `cp` command to copy the secrets template.

```bash
<<<<
    # Copy template files
    cp "build-artifacts-example/add-hosts-example" "$target/add-hosts"
    cp "build-artifacts-example/ssh-config" "$target/ssh-config"
    cp "templates/envrc-template.sh" "$target/envrc"
    cp "templates/instance-run-vars-template.yaml" "$target/instance-run-vars.yaml"
    cp "templates/inventory-physical-example.yaml" "$target/inventory.yaml"
    cp "templates/context-config-template.yaml" "$config_yaml"
====
    # Copy template files
    cp "build-artifacts-example/add-hosts-example" "$target/add-hosts"
    cp "build-artifacts-example/ssh-config" "$target/ssh-config"
    cp "templates/envrc-template.sh" "$target/envrc"
    cp "templates/instance-run-vars-template.yaml" "$target/instance-run-vars.yaml"
    cp "templates/inventory-physical-example.yaml" "$target/inventory.yaml"
    cp "templates/context-config-template.yaml" "$config_yaml"
    cp "templates/context-config-secrets-template.yaml" "$secrets_yaml"
>>>>
```

- [ ] **Step 3: Update final output summary**

In the `# 5. Final UX: Link as active` section (around line 1098), update the `pretty_print` statements to include the new secrets file.

```bash
<<<<
    # 5. Final UX: Link as active
    rm -f build-artifacts
    ln -s "$target" build-artifacts
    pretty_print "Context '${name}' created and linked as active." "SUCCESS"
    pretty_print "Location: ${target}"
    pretty_print "Config: ${config_yaml}"
    pretty_print "\nNext Steps:" "INFO"
    pretty_print "1. Edit ${config_yaml} to match your environment's IPs and nodes."
====
    # 5. Final UX: Link as active
    rm -f build-artifacts
    ln -s "$target" build-artifacts
    pretty_print "Context '${name}' created and linked as active." "SUCCESS"
    pretty_print "Location: ${target}"
    pretty_print "Config: ${config_yaml}"
    pretty_print "Secrets: ${secrets_yaml}"
    pretty_print "\nNext Steps:" "INFO"
    pretty_print "1. Edit ${config_yaml} and ${secrets_yaml} to match your environment."
>>>>
```

### Task 2: Verification

**Files:**
- N/A

- [ ] **Step 1: Check syntax**

Run: `bash -n scripts/instance-context.sh`
Expected: No output (success).

- [ ] **Step 2: Run manual test**

Run: `./scripts/instance-context.sh -c test-auto-secrets`
(When prompted to sync to GSM, choose 'n')

Expected output should include:
```
Secrets: configs/test-auto-secrets-context-secrets.yaml
Next Steps:
1. Edit configs/test-auto-secrets-context.yaml and configs/test-auto-secrets-context-secrets.yaml to match your environment.
```

- [ ] **Step 3: Verify files exist**

Run: `ls -l configs/test-auto-secrets-context*`
Expected: Both `.yaml` and `-secrets.yaml` files exist.

- [ ] **Step 4: Cleanup**

Run:
```bash
rm -rf build-artifacts-test-auto-secrets
rm configs/test-auto-secrets-context.yaml
rm configs/test-auto-secrets-context-secrets.yaml
rm build-artifacts
```

- [ ] **Step 5: Commit changes**

Run:
```bash
git add scripts/instance-context.sh
git commit -m "feat: automatically create secrets file when creating context"
```
