# Design Spec: Regional Secrets Bug Fix in Instance Context

## Status
Approved

## Context
A customer reported a bug in `scripts/instance-context.sh` when dealing with Google Secret Manager (GSM). The script attempts to create secrets globally first, and if that fails, falls back to regional creation. However, the `is_regional` flag was being set to `true` unconditionally after the regional creation attempt, regardless of whether the command succeeded or failed. 

If a user lacked permissions to create regional secrets, `is_regional` was incorrectly set to `true`, causing the subsequent versions add command to fail with an `INVALID_ARGUMENT` error because the secret path did not exist.

## Requirements
- The script must only set `is_regional=true` if the regional secret creation successfully executes.
- If both global and regional secret creation attempts fail, the script must fail fast, log a clear error message, and abort the `gsm_put` operation.

## Proposed Logic Changes
The `gsm_put` function will be updated to explicitly check the return code of the creation commands. If creation fails, it will print an error and `return 1`.

## Verification Plan
1. Code review of `gsm_put`.
2. Manual verification that a failed creation correctly logs an error and aborts.
