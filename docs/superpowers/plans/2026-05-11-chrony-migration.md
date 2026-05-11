# Chrony Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `systemd-timesyncd` with `chrony` for robust time synchronization on Ubuntu 22.04+.

**Architecture:** 
- Transition tasks in `roles/ready-linux/tasks/setup-time-sync.yaml`.
- New Jinja2 template for `chrony.conf`.
- Cleanup of old `timesyncd.conf.j2`.
- Updated `molecule` verification.

**Tech Stack:** Ansible, Ubuntu 22.04, Chrony.

---

### Task 1: Create Chrony Configuration Template

**Files:**
- Create: `roles/ready-linux/templates/chrony.conf.j2`

- [ ] **Step 1: Write the template**

```jinja2
# Created by Ansible
# Chrony configuration for robust time sync

{% for server in timesync_servers %}
pool {{ server }} iburst
{% endfor %}

driftfile /var/lib/chrony/chrony.drift
logdir /var/log/chrony
maxupdateskew 100.0
rtcsync
makestep 1 3
```

- [ ] **Step 2: Commit template**

```bash
git add roles/ready-linux/templates/chrony.conf.j2
git commit -m "feat(ready-linux): add chrony.conf template"
```

### Task 2: Update Time Sync Tasks

**Files:**
- Modify: `roles/ready-linux/tasks/setup-time-sync.yaml`

- [ ] **Step 1: Replace timesyncd tasks with chrony tasks**

```yaml
- name: Remove NTP Package
  apt:
    pkg:
    - ntp
    state: absent
  tags:
  - time-sync-setup
  when:
  - target_os == "ubuntu"

- name: Disable systemd-timesyncd
  systemd:
    name: systemd-timesyncd
    enabled: no
    state: stopped
  tags:
  - time-sync-setup
  when:
  - target_os == "ubuntu"

- name: Install chrony
  apt:
    name: chrony
    state: present
    update_cache: yes
  tags:
  - time-sync-setup
  when:
  - target_os == "ubuntu"

- name: Setup TimeZone Data
  community.general.timezone:
    name: "{{ machine_timezone }}"
  tags:
  - time-sync-setup

- name: Template chrony.conf
  template:
    src: chrony.conf.j2
    dest: /etc/chrony/chrony.conf
    owner: root
    group: root
    mode: 0644
  notify: Reload chrony
  tags:
  - time-sync-setup

- name: Ensure chrony is started and enabled
  systemd:
    name: chrony
    state: started
    enabled: yes
  tags:
  - time-sync-setup
```

- [ ] **Step 2: Cleanup old template file**

Run: `rm roles/ready-linux/templates/timesyncd.conf.j2`

- [ ] **Step 3: Commit task changes**

```bash
git add roles/ready-linux/tasks/setup-time-sync.yaml roles/ready-linux/templates/timesyncd.conf.j2
git commit -m "feat(ready-linux): replace timesyncd with chrony"
```

### Task 3: Add Handler for Chrony

**Files:**
- Create/Modify: `roles/ready-linux/handlers/main.yml` (check if exists)

- [ ] **Step 1: Add chrony reload handler**

```yaml
- name: Reload chrony
  systemd:
    name: chrony
    state: restarted
```

- [ ] **Step 2: Commit handler**

```bash
git add roles/ready-linux/handlers/main.yml
git commit -m "feat(ready-linux): add chrony restart handler"
```

### Task 4: Update Molecule Verification

**Files:**
- Modify: `roles/ready-linux/molecule/default/verify.yml`

- [ ] **Step 1: Add chrony assertions**

```yaml
  - name: Check if chrony is installed
    package:
      name: chrony
      state: present
    check_mode: yes
    register: chrony_install
    failed_when: chrony_install.changed

  - name: Check if chrony service is running
    service:
      name: chrony
      state: started
    check_mode: yes
    register: chrony_service
    failed_when: chrony_service.changed

  - name: Verify systemd-timesyncd is stopped
    service:
      name: systemd-timesyncd
      state: stopped
    check_mode: yes
    register: timesyncd_service
    failed_when: timesyncd_service.changed
```

- [ ] **Step 2: Commit verification**

```bash
git add roles/ready-linux/molecule/default/verify.yml
git commit -m "test(ready-linux): add chrony molecule verification"
```
