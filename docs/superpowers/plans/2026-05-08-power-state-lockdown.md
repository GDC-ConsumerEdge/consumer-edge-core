# Power State Lockdown Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Secure Ubuntu edge nodes against unintended power state changes (shutdown, sleep) while allowing reboot.

**Architecture:** We use systemd-native configuration. We mask specific systemd targets (poweroff, halt, sleep, suspend, hibernate, hybrid-sleep) via ansible, and deploy a custom logind drop-in file to ignore lid/hardware sleep events and repurpose the power button to trigger a reboot. 

**Tech Stack:** Ansible, Systemd, Logind

---

### Task 1: Create Logind Drop-in Configuration Template

**Files:**
- Create: `roles/abm-post-install/templates/logind-lockdown.conf.j2`

- [ ] **Step 1: Write the template**

Create the template file containing the required `systemd-logind` configuration overrides.

```ini
[Login]
# Ignore lid events (prevent sleep on lid close)
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore

# Ignore dedicated sleep/hibernate keys
HandleSuspendKey=ignore
HandleHibernateKey=ignore

# Repurpose the main Power Button to Reboot
HandlePowerKey=reboot
```

- [ ] **Step 2: Commit the template**

```bash
git add roles/abm-post-install/templates/logind-lockdown.conf.j2
git commit -m "feat(power): add logind drop-in template for hardware event lockdown"
```

### Task 2: Implement Ansible Task for Masking and Logind Config

**Files:**
- Modify: `roles/abm-post-install/tasks/main.yml`

- [ ] **Step 1: Write the tasks**

Append the following tasks to the end of the `roles/abm-post-install/tasks/main.yml` file. These tasks apply the logind configuration drop-in, mask the forbidden systemd targets, and restart `systemd-logind`.

```yaml

- name: Create systemd logind configuration directory
  ansible.builtin.file:
    path: /etc/systemd/logind.conf.d
    state: directory
    mode: '0755'

- name: Deploy logind lockdown configuration
  ansible.builtin.template:
    src: logind-lockdown.conf.j2
    dest: /etc/systemd/logind.conf.d/lockdown.conf
    owner: root
    group: root
    mode: '0644'
  notify:
    - Restart systemd-logind

- name: Mask unwanted systemd power state targets
  ansible.builtin.systemd:
    name: "{{ item }}"
    masked: yes
  loop:
    - poweroff.target
    - halt.target
    - sleep.target
    - suspend.target
    - hibernate.target
    - hybrid-sleep.target
```

- [ ] **Step 2: Add the Restart Handler**

Create or modify `roles/abm-post-install/handlers/main.yml` to include the `systemd-logind` restart handler. If the directory or file doesn't exist, create it.

```yaml
---
- name: Restart systemd-logind
  ansible.builtin.systemd:
    name: systemd-logind
    state: restarted
    daemon_reload: yes
```

- [ ] **Step 3: Commit the tasks and handlers**

```bash
git add roles/abm-post-install/tasks/main.yml roles/abm-post-install/handlers/main.yml
git commit -m "feat(power): implement systemd target masking and deploy logind config"
```

### Task 3: Create Automated Verification Script

**Files:**
- Create: `tests/scripts/verify-power-state-lockdown.sh`

- [ ] **Step 1: Write the verification script**

Create a bash script to test that the configurations were applied successfully. Note: This script tests the *state* of the system rather than actually executing power commands, as running `systemctl poweroff` could be disruptive if it incorrectly succeeds.

```bash
#!/bin/bash
set -euo pipefail

echo "Verifying Power State Lockdown..."
FAILED=0

# Check masked targets
TARGETS=("poweroff.target" "halt.target" "sleep.target" "suspend.target" "hibernate.target" "hybrid-sleep.target")

for target in "${TARGETS[@]}"; do
    state=$(systemctl is-enabled "$target" 2>/dev/null || true)
    if [ "$state" == "masked" ]; then
        echo "✅ $target is masked."
    else
        echo "❌ $target is NOT masked (current state: $state)."
        FAILED=1
    fi
done

# Check logind config
LOGIND_CONF="/etc/systemd/logind.conf.d/lockdown.conf"
if [ -f "$LOGIND_CONF" ]; then
    echo "✅ Logind drop-in configuration exists at $LOGIND_CONF."
    
    # Check for specific keys
    if grep -q "HandlePowerKey=reboot" "$LOGIND_CONF"; then
        echo "✅ HandlePowerKey=reboot is set."
    else
        echo "❌ HandlePowerKey=reboot is MISSING."
        FAILED=1
    fi
else
    echo "❌ Logind drop-in configuration MISSING at $LOGIND_CONF."
    FAILED=1
fi

if [ "$FAILED" -eq 1 ]; then
    echo "Verification FAILED."
    exit 1
else
    echo "Verification PASSED."
    exit 0
fi
```

- [ ] **Step 2: Make executable and commit**

```bash
chmod +x tests/scripts/verify-power-state-lockdown.sh
git add tests/scripts/verify-power-state-lockdown.sh
git commit -m "test(power): add verification script for power state lockdown"
```
