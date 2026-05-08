# Instance Context Secrets Automation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automate the creation of `configs/[name]-context-secrets.yaml` alongside the main context configuration when creating a new instance context.

**Architecture:** Modify the `create_context` function in `scripts/instance-context.sh` to copy the `context-config-secrets-template.yaml` to the new secrets configuration path and update the user feedback strings to reference the new file.

**Tech Stack:** Bash

---

### Task 1: Update `scripts/instance-context.sh`

**Files:**
- Modify: `scripts/instance-context.sh`
- Test: Manual execution

- [ ] **Step 1: Declare secrets file variable**

In `scripts/instance-context.sh`, locate the `create_context` function (around line 603). Add the `secrets_yaml` variable below `config_yaml`.

```bash
    local target="build-artifacts-${name}"
    local config_yaml="configs/${name}-context.yaml"
    local secrets_yaml="configs/${name}-context-secrets.yaml"
```

- [ ] **Step 2: Copy secrets template during scaffolding**

In the same function, under `# 2. Scaffolding`, add the `cp` command to copy the secrets template.

```bash
    # Copy template files
    cp "build-artifacts-example/add-hosts-example" "$target/add-hosts"
    cp "build-artifacts-example/ssh-config" "$target/ssh-config"
    cp "templates/envrc-template.sh" "$target/envrc"
    cp "templates/instance-run-vars-template.yaml" "$target/instance-run-vars.yaml"
    cp "templates/inventory-physical-example.yaml" "$target/inventory.yaml"
    cp "templates/context-config-template.yaml" "$config_yaml"
    cp "templates/context-config-secrets-template.yaml" "$secrets_yaml"
```

- [ ] **Step 3: Update final output summary**

In the `# 5. Final UX: Link as active` section, update the `pretty_print` statements to include the new secrets file.

```bash
    # 5. Final UX: Link as active
    rm -f build-artifacts
    ln -s "$target" build-artifacts
    pretty_print "Context '${name}' created and linked as active." "SUCCESS"
    pretty_print "Location: ${target}"
    pretty_print "Config: ${config_yaml}"
    pretty_print "Secrets: ${secrets_yaml}"
    pretty_print "\nNext Steps:" "INFO"
    pretty_print "1. Edit ${config_yaml} and ${secrets_yaml} to match your environment."
    pretty_print "2. Run './scripts/instance-context.sh -g ${name}' to apply changes and upload to GSM."
```

- [ ] **Step 4: Verify syntax**

Run: `bash -n scripts/instance-context.sh`
Expected: No output (clean syntax)

- [ ] **Step 5: Test creation of new context**

Run: `./scripts/instance-context.sh -c test-auto-secrets`
Expected Output (snippet):
```
Location: build-artifacts-test-auto-secrets
Config: configs/test-auto-secrets-context.yaml
Secrets: configs/test-auto-secrets-context-secrets.yaml

Next Steps:
1. Edit configs/test-auto-secrets-context.yaml and configs/test-auto-secrets-context-secrets.yaml to match your environment.
```

- [ ] **Step 6: Verify file creation**

Run: `ls configs/test-auto-secrets*`
Expected Output:
```
configs/test-auto-secrets-context-secrets.yaml
configs/test-auto-secrets-context.yaml
```

- [ ] **Step 7: Cleanup test context**

Run:
```bash
rm -rf build-artifacts-test-auto-secrets
rm configs/test-auto-secrets-context*
rm build-artifacts
```

- [ ] **Step 8: Commit**

```bash
git add scripts/instance-context.sh
git commit -m "feat: automatically create secrets file when creating context"
```
