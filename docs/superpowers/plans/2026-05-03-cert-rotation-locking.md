# Cert Rotation GCS Lock Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a GCS-based distributed lock for staggered, atomic certificate rotation across 3 nodes.

**Architecture:** Uses `gcloud storage` preconditions for atomic locking, a 2-hour TTL for deadlock recovery, and Ansible-templated cron jobs staggered by 1 minute.

**Tech Stack:** Bash, GCS, Ansible, Jinja2.

---

### Task 1: Update Global Variables
**Files:**
- Modify: `inventory/group_vars/all.yaml`

- [ ] **Step 1: Add TTL and Cron variables**
Add the following near the `snapshot_gcs_bucket_base` variable:
```yaml
# Distributed lock TTL for cluster-wide operations (e.g. cert rotation)
cert_rotation_lock_ttl_hours: 2

# Certificate Rotation Cron Schedule
# Default runs every 3 months at 2 AM
cert_rotation_cron_months: "*/3"
cert_rotation_cron_hour: "2"
```
- [ ] **Step 2: Commit**
`git commit -m "config: add cert rotation locking and cron variables"`

---

### Task 3: Implement GCS Locking & Rotation Script
**Files:**
- Modify: `roles/abm-post-install/templates/rotate-k8s-certs.sh.j2`

- [ ] **Step 1: Implement the locking wrapper and user's rotation logic**
Update the template to include the acquisition, TTL check, rotation logic, sleep, and trap.
- [ ] **Step 2: Ensure all variables (`snapshot_gcs_bucket_base`, etc.) are correctly referenced.**
- [ ] **Step 3: Commit**
`git commit -m "feat: implement GCS locking and cert rotation logic in template"`

---

### Task 3: Implement Staggered Cron Template
**Files:**
- Modify: `roles/abm-post-install/templates/rotate-k8s-certs-cron.sh.j2`

- [ ] **Step 1: Use `node_index` to stagger the cron minute**
```jinja2
{% set node_index = play_hosts.index(inventory_hostname) | default(0) %}
{{ node_index % 60 }} {{ cert_rotation_cron_hour }} * {{ cert_rotation_cron_months }} * ...
```
- [ ] **Step 2: Commit**
`git commit -m "feat: add staggered cron scheduling for cert rotation"`

---

### Task 4: Local Verification (Simulation)
**Files:**
- Create: `tests/simulate_cluster_lock.sh`

- [ ] **Step 1: Create a simulator that mocks GCS and runs 3 instances of the script.**
- [ ] **Step 2: Verify only one instance succeeds and others wait/exit.**
- [ ] **Step 3: Verify TTL cleanup works.**
- [ ] **Step 4: Commit**
`git commit -m "test: add multi-node lock simulator"`

---

### Task 5: Final Review & Cleanup
- [ ] **Step 1: Remove test simulator.**
- [ ] **Step 2: Final audit of `all-verify.yml` and `roles/abm-post-install/tasks/main.yml` to ensure templates are being deployed.**
- [ ] **Step 3: Commit**
`git commit -m "chore: final cleanup of cert rotation feature"`
