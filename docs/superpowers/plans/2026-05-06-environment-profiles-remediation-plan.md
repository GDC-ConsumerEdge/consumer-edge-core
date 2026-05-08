# Environment Profiles Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the Ansible roles to clean up environment configurations, migrating away from fragile shell expansions in `/etc/environment` and heavy unconditional executions in `/etc/profile.d/` for greenfield deployments.

**Architecture:** We will manage `gcloud` paths via the existing symlinks rather than `/etc/environment`, wrap `gcloud` auth and `kubectl` completion scripts in `/etc/profile.d/01-gcloud-auth.sh` with an interactive shell (`$PS1`) check, migrate user `.bashrc` aliases and PS1 overrides to the system-wide `/etc/bash.bashrc` (Ubuntu) or `/etc/bashrc` (RHEL), and remove the `-l` login flag from the `gcloud-update-cron.j2` cron execution.

**Tech Stack:** Ansible, Bash, PAM environment

---

### Task 1: Remove Redundant PATH Manipulation

**Files:**
- Modify: `roles/google-tools/tasks/main.yml`
- Create: `tests/plan-tests/test_task1.sh`

- [ ] **Step 1: Write the failing test**

```bash
mkdir -p tests/plan-tests
cat << 'EOF' > tests/plan-tests/test_task1.sh
#!/bin/bash
if grep -q "Add gcloud to PATH on all shells" roles/google-tools/tasks/main.yml; then
    echo "FAIL: Redundant PATH manipulation task still exists."
    exit 1
fi
echo "PASS"
EOF
chmod +x tests/plan-tests/test_task1.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./tests/plan-tests/test_task1.sh`
Expected: FAIL with "Redundant PATH manipulation task still exists."

- [ ] **Step 3: Write minimal implementation**

Modify `roles/google-tools/tasks/main.yml` to remove the following block (around line 189):

```yaml
#### Setting up non-interactive PATH for gcloud
  - name: Add gcloud to PATH on all shells (including non-interactive)
    lineinfile:
      path: /etc/environment
      regexp: 'PATH="(\/usr\/local\/sbin:\/usr\/local\/bin:\/usr\/sbin:\/usr\/bin:\/sbin:\/bin:\/usr\/games:\/usr\/local\/games:\/snap\/bin)"$' #uugghhly...but works
      line: 'PATH="{{ tools_base_path }}/google-cloud-sdk/bin:\1"' #prepend gcloud (snap auto installs gcloud on GCE instances)
      backrefs: yes
      state: present
    tags:
    - profile
    - initial-install
    - non-interactive-shell
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./tests/plan-tests/test_task1.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add roles/google-tools/tasks/main.yml tests/plan-tests/test_task1.sh
git commit -m "refactor: remove redundant PATH manipulation from /etc/environment"
```

### Task 2: Refactor Profile Initialization

**Files:**
- Modify: `roles/google-tools/tasks/main.yml`
- Create: `roles/google-tools/templates/01-gcloud-auth.sh.j2`
- Create: `tests/plan-tests/test_task2.sh`

- [ ] **Step 1: Write the failing test**

```bash
cat << 'EOF' > tests/plan-tests/test_task2.sh
#!/bin/bash
if grep -q "Add node GSA activation script to /etc/profile.d" roles/google-tools/tasks/main.yml; then
    echo "FAIL: Old profile tasks still exist in main.yml"
    exit 1
fi

if [ ! -f "roles/google-tools/templates/01-gcloud-auth.sh.j2" ]; then
    echo "FAIL: Template 01-gcloud-auth.sh.j2 does not exist"
    exit 1
fi
echo "PASS"
EOF
chmod +x tests/plan-tests/test_task2.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./tests/plan-tests/test_task2.sh`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

First, create `roles/google-tools/templates/01-gcloud-auth.sh.j2` with the new interactive shell guard:

```bash
if [ -n "$PS1" ]; then
    # Authenticate if needed
    ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null)
    if [ "$ACTIVE_ACCOUNT" != "{{ expected_gsa_email | default('') }}" ]; then
        gcloud auth activate-service-account --key-file={{ remote_keys_folder }}/node-gsa.json --project {{ google_project_id }} --quiet 2>/dev/null
    fi
    
    # Load completions
    if [ -f '{{ tools_base_path }}/google-cloud-sdk/completion.bash.inc' ]; then 
        source '{{ tools_base_path }}/google-cloud-sdk/completion.bash.inc'
    fi
fi
```

Second, edit `roles/google-tools/tasks/main.yml` to remove the old blocks for bash completion and GSA activation (around lines 190-237):
Remove:
- "Check for '/etc/profile.d/bash_completion.sh'"
- "Missing '/etc/profile.d/bash_completion.sh', touching to create"
- "Add gcloud BASH completion"
- "Add node GSA activation script to /etc/profile.d"
- "Add node GSA activation script to /etc/profile.d # NOTE: This will be removed in"

Replace all of those with this single consolidated template task:

```yaml
  - name: Add interactive gcloud auth and completion script to /etc/profile.d
    template:
      src: 01-gcloud-auth.sh.j2
      dest: /etc/profile.d/01-gcloud-auth.sh
      mode: '0755'
    tags:
    - profile
    - initial-install
    - non-interactive-shell
    - gcloud-setup
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./tests/plan-tests/test_task2.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add roles/google-tools/tasks/main.yml roles/google-tools/templates/01-gcloud-auth.sh.j2 tests/plan-tests/test_task2.sh
git commit -m "refactor: consolidate gcloud auth and completion into guarded profile script"
```

### Task 3: Clean up abm-post-install redundant task

**Files:**
- Modify: `roles/abm-post-install/tasks/main.yml`
- Create: `tests/plan-tests/test_task3.sh`

- [ ] **Step 1: Write the failing test**

```bash
cat << 'EOF' > tests/plan-tests/test_task3.sh
#!/bin/bash
if grep -q "Remove provisioning GSA profile" roles/abm-post-install/tasks/main.yml; then
    echo "FAIL: Redundant removal task still exists"
    exit 1
fi
echo "PASS"
EOF
chmod +x tests/plan-tests/test_task3.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./tests/plan-tests/test_task3.sh`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

Edit `roles/abm-post-install/tasks/main.yml` and remove this task (around line 75):

```yaml
- name: Remove provisioning GSA profile
  file:
    path: /etc/profile.d/99-gcloud-auth-provisioning-gsa.sh
    state: absent
  tags:
  - profile
  - initial-install
  - non-interactive-shell
  - gcloud-setup
  - gsa-removal
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./tests/plan-tests/test_task3.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add roles/abm-post-install/tasks/main.yml tests/plan-tests/test_task3.sh
git commit -m "refactor: remove redundant provisioning GSA profile cleanup task"
```

### Task 4: Move bash customizations to global bashrc

**Files:**
- Modify: `roles/abm-post-install/tasks/add-kube-ps1.yml`
- Create: `tests/plan-tests/test_task4.sh`

- [ ] **Step 1: Write the failing test**

```bash
cat << 'EOF' > tests/plan-tests/test_task4.sh
#!/bin/bash
if grep -q "path: \"/home/{{ item }}/.bashrc\"" roles/abm-post-install/tasks/add-kube-ps1.yml; then
    echo "FAIL: Still modifying individual user bashrc files."
    exit 1
fi
echo "PASS"
EOF
chmod +x tests/plan-tests/test_task4.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./tests/plan-tests/test_task4.sh`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

Edit `roles/abm-post-install/tasks/add-kube-ps1.yml`. Replace all four `lineinfile` tasks that modify `/home/{{ item }}/.bashrc` (starting around line 54) with these OS-specific global tasks. Remove the `loop:` directives entirely from these tasks.

```yaml
  - name: Add source of kube-ps1 to bash.bashrc (Ubuntu)
    lineinfile:
      path: "/etc/bash.bashrc"
      line: 'source "{{ tools_base_path}}/kube-ps1/kube-ps1-{{ kube_ps1_version }}/kube-ps1.sh"'
    tags:
    - optional
    - kube-ps1
    when:
    - target_os == "ubuntu"

  - name: Add kube_ps1 to PS1 line (Ubuntu)
    lineinfile:
      path: "/etc/bash.bashrc"
      line: PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\] $(kube_ps1):\[\033[01;34m\]\w\[\033[00m\]\$ '
    tags:
    - optional
    - kube-ps1
    when:
    - target_os == "ubuntu"

  - name: Add k alias for kubectl (Ubuntu)
    lineinfile:
      path: "/etc/bash.bashrc"
      line: alias k=kubectl
    tags:
    - optional
    - kube-ps1
    when:
    - target_os == "ubuntu"

  - name: Add completion for alias (Ubuntu)
    lineinfile:
      path: "/etc/bash.bashrc"
      line: complete -F __start_kubectl k
    tags:
    - optional
    - kube-ps1
    when:
    - target_os == "ubuntu"

  - name: Add source of kube-ps1 to bashrc (RedHat)
    lineinfile:
      path: "/etc/bashrc"
      line: 'source "{{ tools_base_path}}/kube-ps1/kube-ps1-{{ kube_ps1_version }}/kube-ps1.sh"'
    tags:
    - optional
    - kube-ps1
    when:
    - target_os == "redhat"

  - name: Add kube_ps1 to PS1 line (RedHat)
    lineinfile:
      path: "/etc/bashrc"
      line: PS1='[\u@\h \W $(kube_ps1)]\$ '
    tags:
    - optional
    - kube-ps1
    when:
    - target_os == "redhat"

  - name: Add k alias for kubectl (RedHat)
    lineinfile:
      path: "/etc/bashrc"
      line: alias k=kubectl
    tags:
    - optional
    - kube-ps1
    when:
    - target_os == "redhat"

  - name: Add completion for alias (RedHat)
    lineinfile:
      path: "/etc/bashrc"
      line: complete -F __start_kubectl k
    tags:
    - optional
    - kube-ps1
    when:
    - target_os == "redhat"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./tests/plan-tests/test_task4.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add roles/abm-post-install/tasks/add-kube-ps1.yml tests/plan-tests/test_task4.sh
git commit -m "refactor: migrate bash customizations to global /etc/bash.bashrc and /etc/bashrc"
```

### Task 5: Cron Job Optimization

**Files:**
- Modify: `roles/ready-linux/templates/gcloud-update-cron.j2`
- Create: `tests/plan-tests/test_task5.sh`

- [ ] **Step 1: Write the failing test**

```bash
cat << 'EOF' > tests/plan-tests/test_task5.sh
#!/bin/bash
if grep -q "runuser -l" roles/ready-linux/templates/gcloud-update-cron.j2; then
    echo "FAIL: Cron job still forces a login shell using -l."
    exit 1
fi
echo "PASS"
EOF
chmod +x tests/plan-tests/test_task5.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./tests/plan-tests/test_task5.sh`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

Edit `roles/ready-linux/templates/gcloud-update-cron.j2`. Change line 18 to remove the `-l` flag and correct the minor syntax typos (`scritps` -> `scripts` and extra trailing quote).

Change:
```bash
{{ gcloud_update_cron_value }} runuser -l '{{ ansible_user  }}' -c '{{ abm_install_folder }}/scritps/gcloud-update-script.sh' >> '{{ gcloud_update_log }}''
```

To:
```bash
{{ gcloud_update_cron_value }} runuser '{{ ansible_user }}' -c '{{ abm_install_folder }}/scripts/gcloud-update-script.sh' >> '{{ gcloud_update_log }}'
```

- [ ] **Step 4: Run test to verify it passes**

Run: `./tests/plan-tests/test_task5.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add roles/ready-linux/templates/gcloud-update-cron.j2 tests/plan-tests/test_task5.sh
git commit -m "fix: optimize gcloud update cron by removing login shell requirement"
```
