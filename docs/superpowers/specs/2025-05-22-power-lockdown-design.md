# Design Doc: Power State Lockdown Implementation

## Goal
Implement Ansible automation to prevent unintended power state changes on Ubuntu edge nodes while maintaining reboot capability.

## Scope
- Modify `roles/abm-post-install/tasks/main.yml` to include lockdown tasks.
- Create `roles/abm-post-install/handlers/main.yml` for service restarts.
- Ensure consistency with existing tagging patterns.

## Design

### Tasks
The following tasks will be added to `roles/abm-post-install/tasks/main.yml`:
1. **Create directory**: Ensure `/etc/systemd/logind.conf.d` exists.
2. **Deploy template**: Use `logind-lockdown.conf.j2` to create `/etc/systemd/logind.conf.d/lockdown.conf`.
3. **Mask targets**: Mask forbidden systemd targets (poweroff, halt, sleep, suspend, hibernate, hybrid-sleep).

Each task will include the following tags for consistency:
- `abm-post-install`
- `power-lockdown`

### Handlers
A new handler `Restart systemd-logind` will be defined in `roles/abm-post-install/handlers/main.yml` to restart the service when the configuration changes.

## Verification
- Syntax validation of modified YAML files.
- Manual inspection of file paths and permissions.

## Implementation Plan
1. Create `roles/abm-post-install/handlers/` directory.
2. Write `roles/abm-post-install/handlers/main.yml`.
3. Append tasks to `roles/abm-post-install/tasks/main.yml`.
4. Run `ansible-lint` (if available) or basic YAML check.
5. Commit changes.
