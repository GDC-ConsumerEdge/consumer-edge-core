# Specification: Environment Profiles Remediation (Greenfield)

## 1. Overview
This specification outlines the technical approach for resolving architectural anti-patterns in how environment configurations (`/etc/environment`, `/etc/profile.d/`, and `.bashrc`) are managed within the `ready-linux` and related roles. 

**Scope Constraint:** This design is strictly for greenfield (new) deployments. Backward compatibility or active cleanup of previously provisioned systems is explicitly out of scope.

## 2. Global Environment (`/etc/environment`)
The `/etc/environment` file is read by the PAM `pam_env` module and only supports static `KEY=VAL` definitions, not shell expansion.

*   **Implementation:** 
    *   Remove the `lineinfile` task in the `google-tools` role that attempts to append `gcloud` to the system `PATH` (e.g., `PATH=$PATH:...`).
    *   Rely entirely on the existing `google-tools` tasks that create symlinks in `/usr/bin/` (or `/usr/local/bin/`) for utilities like `gcloud`, `kubectl`, and `bmctl`.

## 3. Profile Initialization (`/etc/profile.d/`)
Scripts in `/etc/profile.d/` are sourced unconditionally for all login shells, causing significant latency (~1-2 seconds) during non-interactive SSH connections or cron jobs using `runuser -l`.

*   **Implementation:**
    *   Consolidate the GSA authentication logic into a single script (e.g., `/etc/profile.d/01-gcloud-auth.sh`).
    *   Wrap expensive commands in an interactive shell guard. 
    *   Example logic for the script template:
        ```bash
        if [ -n "$PS1" ]; then
            # Authenticate if needed
            ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null)
            if [ "$ACTIVE_ACCOUNT" != "{{ expected_gsa_email }}" ]; then
                gcloud auth activate-service-account --key-file={{ remote_keys_folder }}/node-gsa.json --project {{ google_project_id }} --quiet
            fi
            
            # Load completions
            source <(kubectl completion bash) 2>/dev/null
        fi
        ```

## 4. Interactive Shell Customization (`bashrc`)
Currently, UI/UX enhancements like `kube-ps1` and aliases are injected directly into specific users' `~/.bashrc` files via Ansible loops.

*   **Implementation:**
    *   Modify the `abm-post-install` (specifically `add-kube-ps1.yml`) tasks.
    *   Inject the `kube-ps1` source, `PS1` variable override, and `alias k=kubectl` directly into the global bash configuration:
        *   Ubuntu: `/etc/bash.bashrc`
        *   RHEL: `/etc/bashrc`
    *   Do not implement cleanup tasks for individual user `~/.bashrc` files.

## 5. Cron Job Optimization
The `gcloud-update` cron job forces a full login shell, which incurs unnecessary overhead.

*   **Implementation:**
    *   Update the `gcloud-update-cron.j2` template to remove the `-l` flag from the `runuser` command.
    *   Ensure the cron script relies on the symlinks established in `/usr/bin/` and the cached authentication state.
