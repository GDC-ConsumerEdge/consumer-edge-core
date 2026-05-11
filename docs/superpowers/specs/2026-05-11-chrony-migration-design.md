# Design Spec: Chrony Time Synchronization

**Date:** 2026-05-11
**Topic:** Replace `systemd-timesyncd` with `chrony` on Ubuntu 22.04+

## 1. Goal
Replace the existing `systemd-timesyncd` configuration in the `ready-linux` role with `chrony` to provide more robust and faster time synchronization (using `iburst` and `makestep`).

## 2. Architecture
The implementation involves:
- Updating `roles/ready-linux/tasks/setup-time-sync.yaml` to handle package transition.
- Creating a new template `roles/ready-linux/templates/chrony.conf.j2`.
- Removing the obsolete `roles/ready-linux/templates/timesyncd.conf.j2`.

## 3. Implementation Details

### 3.1 Task Workflow
1.  **Stop/Disable `systemd-timesyncd`**: Ensure the service is stopped to prevent port conflicts (though chrony usually handles this, explicit is better).
2.  **Remove `ntp`**: Continue ensuring legacy `ntp` is absent.
3.  **Install `chrony`**: Use `apt` to install the `chrony` package.
4.  **Set Timezone**: Maintain current `machine_timezone` logic.
5.  **Configure `chrony.conf`**: Template out `/etc/chrony/chrony.conf`.
6.  **Manage Service**: Ensure `chrony` service (usually `chrony.service` on Ubuntu) is enabled and started.

### 3.2 Configuration (`chrony.conf.j2`)
- **Servers**: Loop through `timesync_servers` using `pool {{ item }} iburst`.
- **Drift/Log**: Standard `/var/lib/chrony/chrony.drift` and `/var/log/chrony`.
- **Step**: `makestep 1 3` to allow quick initial sync.
- **RTC**: `rtcsync` to update hardware clock.

## 4. Testing & Verification
### 4.1 Automated Testing (Molecule)
- Add a verification step in `roles/ready-linux/molecule/default/verify.yml` to:
    - Check if `chrony` package is installed.
    - Check if `chrony.service` is running and enabled.
    - Verify `systemd-timesyncd` is stopped or disabled.
    - (Optional) Use `chronyc sources` to verify reachability if the environment allows.

### 4.2 Manual Verification
- `chronyc sources -v` to see synchronized servers.
- `chronyc tracking` to see performance and drift.
- `systemctl status chrony` to ensure service health.

## 5. Scope
This change is restricted to the `ready-linux` role and specifically target Ubuntu 22.04+ as per project standards.
