# Design: Power State Lockdown for Ubuntu Edge Nodes

**Date:** 2026-05-08
**Topic:** Power State Control
**Status:** Approved (Brainstorming Phase)

## Overview
For headless edge nodes, it is critical to prevent accidental or unauthorized power downs that might require physical intervention to recover. This design locks down the operating system to prevent "Shutdown", "Hibernate", and "Sleep" states while maintaining the ability to "Reboot".

## Goals
- **Disable** all software-initiated shutdown, hibernate, and suspend actions.
- **Ignore** hardware-initiated sleep events (e.g., laptop lid close).
- **Repurpose** the physical power button to trigger a clean "Reboot" instead of a "Power Off".
- **Allow** clean system reboots via software and hardware.

## Technical Design

### 1. Systemd Target Masking
We will use systemd's masking mechanism to prevent the system from entering unwanted power states. Masking symlinks the unit file to `/dev/null`, making it impossible to start the unit even by the root user or as a dependency.

**Targets to Mask:**
- `poweroff.target`
- `halt.target`
- `sleep.target`
- `suspend.target`
- `hibernate.target`
- `hybrid-sleep.target`

**Command:**
```bash
sudo systemctl mask poweroff.target halt.target sleep.target suspend.target hibernate.target hybrid-sleep.target
```

### 2. Logind Configuration
We will configure `systemd-logind` to handle ACPI and hardware button events according to our requirements.

**File:** `/etc/systemd/logind.conf` (or a drop-in in `/etc/systemd/logind.conf.d/lockdown.conf`)

**Settings:**
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

## Verification Plan

### Software Verification
1. **Attempt Shutdown:** Run `sudo systemctl poweroff`.
   - *Expected:* Command fails with an error indicating the unit is masked.
2. **Attempt Reboot:** Run `sudo systemctl reboot`.
   - *Expected:* System reboots normally.
3. **Check Mask Status:** Run `systemctl status poweroff.target`.
   - *Expected:* Output shows `loaded: masked (/dev/null; masked)`.

### Hardware Verification (If applicable)
1. **Lid Close:** If the edge node has a lid, close it.
   - *Expected:* System remains fully active (checked via ping/SSH).
2. **Power Button:** Press the physical power button once.
   - *Expected:* System initiates a clean reboot cycle.

## Alternatives Considered
- **Polkit Rules:** Rejected as it doesn't handle ACPI events as cleanly as `logind.conf` and is more complex for a simple "deny all" requirement.
- **GRUB Lockdown:** While useful for total security, it was deemed out of scope for the immediate requirement of preventing OS-level shutdowns.

## Risks & Mitigations
- **Risk:** No way to power off cleanly via software.
- **Mitigation:** User acknowledges that physical power removal or BIOS/POST-level intervention is required for a total power-off.
