# Issue: "cronjob: command not found" during interactive login

## Symptoms
When any user other than `abm-admin` logs into the provisioned cluster interactively, they are presented with the following error:

```
/usr/lib/python3/dist-packages/CommandNotFound/db/db.py:6: Warning: W:Unable to read /etc/apt/apt.conf.d/20auto-upgrades - open (13: Permission denied)
  apt_pkg.init()
/usr/lib/python3/dist-packages/CommandNotFound/CommandNotFound.py:139: Warning: W:Unable to read /etc/apt/apt.conf.d/20auto-upgrades - open (13: Permission denied)
  apt_pkg.init()
cronjob: command not found
```

## Immediate Workaround
The Python stack trace and `apt_pkg.init()` warnings are secondary symptoms caused by the `command-not-found` handler trying to search for the unknown `cronjob` command. Because the Ansible playbook originally deployed `/etc/apt/apt.conf.d/20auto-upgrades` with `0600` permissions (root-only), the handler threw a warning for non-root users. 

**Workaround Applied:**
* The permissions for `/etc/apt/apt.conf.d/20auto-upgrades` have been changed to `644` in `roles/ready-linux/tasks/ubuntu-update-automation.yml` and directly on `edge-1`. This suppresses the Python stack trace.

## Deep Dive Required
The root cause remains unresolved: **Something is evaluating the string `cronjob` as a command when the interactive shell starts.**

### Investigation Completed So Far:
* **Dotfiles:** Checked `~/.bashrc`, `~/.profile` for `abm-admin` and `el-gato`. (Identical, no `cronjob` string).
* **System Profiles:** Checked `/etc/profile`, `/etc/profile.d/*.sh`, `/etc/bash.bashrc`. (Clean).
* **Bash Completions:** Checked `kubectl completion bash`, `gcloud` completions, and `/etc/bash_completion.d/*`. 
* **Cron & Systemd:** Checked `/etc/cron.*`, PAM modules, systemd user `linger` services.
* **Tracing:** Ran `strace -f -e execve` and `bash -x -l` to trace the login process. The `cronjob` execution does not occur during standard automated non-interactive or non-terminal logins.

### Next Steps for Investigation:
1. **Client-Side Injection:** Check if the user's terminal emulator (e.g., iTerm2, Tmux, Byobu) or local `.ssh/config` is injecting the command `cronjob` automatically upon a successful SSH connection.
2. **Bash History Anomalies:** Determine if the shell is attempting to replay a failed history expansion or a botched `PROMPT_COMMAND` that was corrupted in a specific terminal state.
3. **Reproduce from Scratch:** Observe the exact keystrokes and SSH client configurations used when the error is generated to ensure no local scripts are wrapping the SSH command.