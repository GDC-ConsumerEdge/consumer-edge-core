# Technical Debt: Environment Profiles (`ready-linux` role)

## Overview

Analysis of the `@roles/ready-linux` role and its associated dependencies (`google-tools`, `set-proxy`, `abm-install`) reveals architectural anti-patterns in how environment configuration files (`/etc/environment`, `/etc/profile.d/`, and `.bashrc`) are managed. These patterns contribute to **long SSH login times**, **fragile system paths**, and **duplicate functionality**, creating friction for interactive sessions while causing unpredictable behavior in non-interactive (cron/provisioning) sessions.

## Findings & Anti-Patterns

### 1. System-wide Configuration (`/etc/environment`)
*   **Shell Expansion Bug:** In `google-tools`, `PATH` is appended using `PATH=$PATH:...`. `/etc/environment` is read by the PAM `pam_env` module; it is a static list of `KEY=VAL` pairs and **does not support shell variable expansion**. This results in a literal `$PATH` string being set.
*   **Regex Fragility:** `google-tools` uses a complex regex to prepend the GCloud SDK path to `/etc/environment`. If the OS default `PATH` differs even slightly from the regex (e.g., a missing `/snap/bin`), the configuration fails silently.
*   **Proxy Bloat:** `set-proxy` adds multiple proxy variables here. This is correct for static values, but redundant when combined with `gcloud config` and `.curlrc` settings managed elsewhere.

### 2. Login Shell Initialization (`/etc/profile.d/`)
*   **Performance Bottlenecks:** `abm-install` and `google-tools` add scripts to `profile.d` that run `source <(kubectl completion bash)` and `gcloud auth activate-service-account`.
    *   **Impact:** `kubectl completion` takes ~200-500ms to generate. `gcloud auth` can take 1-2 seconds. Running these unconditionally on *every* SSH login or `sudo -i` significantly slows down the interactive experience.
*   **Bashisms in Global Profiles:** Using `source <(...)` is a Bash-specific syntax. `/etc/profile` sources `profile.d` for *all* login shells (including `sh`, `zsh`, `dash`). If a user or system process uses a non-bash shell, these scripts will cause errors or hang.
*   **Redundant Auth:** Multiple scripts (`01-gcloud-auth...` and `99-gcloud-auth...`) attempt to authenticate GSAs.

### 3. User Interactive Customization (`.bashrc`)
*   **Direct Modification:** `abm-post-install` modifies `/home/{{ user }}/.bashrc` directly to add `kube-ps1` and aliases.
*   **Inconsistency:** Some users get the `k` alias, while others (or system accounts) do not, depending on which Ansible loops ran.

### 4. Interactive vs. Non-interactive Contexts
*   **Login Shell Overhead:** Cron jobs in `ready-linux` use `runuser -l`. This forces a full login shell, meaning every cron job incurs the 2+ second penalty of the heavy `profile.d` scripts mentioned above.
*   **Context Drift:** Non-interactive shells that are *not* login shells (e.g., `ssh host "command"`) miss the variables set in `profile.d`.

---

## Remediation Recommendations

### 1. Re-architect `/etc/environment`
*   **Stop using `PATH` in `/etc/environment`:** Instead, rely on symlinks in `/usr/local/bin` (or `/usr/bin`) for all major tools. The project already does this for `kubectl`, `bmctl`, etc. This is the most robust way to ensure tools are available to all shells without fragile regex parsing.
*   **Keep it Static:** Only use `/etc/environment` for fixed values that never change during a session (e.g., `GOOGLE_APPLICATION_CREDENTIALS`, `HTTP_PROXY`).

### 2. Refactor `/etc/profile.d/` Scripts
*   **Protect with Interactive Check:** Wrap completion and aliases in a check for an interactive shell:
    ```bash
    if [ -n "$PS1" ]; then
        # Only runs for interactive shells
        source <(kubectl completion bash) 2>/dev/null
    fi
    ```
*   **Conditional Authentication:** Only run `gcloud auth` if the current active account is not what's expected:
    ```bash
    ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format='value(account)')
    if [ "$ACTIVE_ACCOUNT" != "{{ expected_gsa_email }}" ]; then
        gcloud auth activate-service-account ...
    fi
    ```
*   **Consolidate:** Use a single, well-documented script (e.g., `/etc/profile.d/consumer-edge-core.sh`) instead of multiple fragmented files.

### 3. Centralize Bash Customization
*   **Use `/etc/bash.bashrc` (Ubuntu) or `/etc/bashrc` (RHEL):** For global aliases (`alias k=kubectl`) and prompts like `kube-ps1` that you want *all* interactive bash users to have, use the global bashrc instead of looping through individual home directories.
*   **Move "Flavor" out of `profile.d`:** Keep `profile.d` strictly for environment variables and use the global `bashrc` for "UI/UX" features.

### 4. Optimize Headless Operations
*   **Ensure core variables are in `/etc/environment`:** By putting `GOOGLE_APPLICATION_CREDENTIALS` and `KUBECONFIG` in `/etc/environment`, even a "naked" non-interactive shell will have the correct context without needing to source a heavy profile.
*   **Optimize Cron Execution:** If variables are correctly set in `/etc/environment`, cron jobs can run without `-l` (login), improving system performance and reducing log noise.

---

### Summary Matrix

| Feature | Recommended Location | Rationale |
| :--- | :--- | :--- |
| **Static Env Vars** (`HTTP_PROXY`, `GSA_JSON`) | `/etc/environment` | Available to ALL processes (Cron, SSH, Local). |
| **Dynamic Env Vars** (`KUBECONFIG`) | `/etc/profile.d/*.sh` | Supports logic, but should be kept minimal. |
| **Shell Aliases / PS1** (`alias k`, `kube-ps1`) | `/etc/bash.bashrc` | Strictly for interactive Bash users. |
| **GCloud/K8s Completion** | `/etc/bash.bashrc` | High performance hit; only needed interactively. |
| **GSA Authentication** | One-time Ansible Task | Authenticate during provisioning; avoid doing it on every login. |
