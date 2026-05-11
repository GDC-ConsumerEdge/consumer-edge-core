#!/bin/bash
set -euo pipefail

echo "Verifying Power State Lockdown..."
FAILED=0

# Check masked targets
TARGETS=("poweroff.target" "halt.target" "sleep.target" "suspend.target" "hibernate.target" "hybrid-sleep.target")

for target in "${TARGETS[@]}"; do
    state=$(systemctl is-enabled "$target" 2>/dev/null || true)
    if [ "$state" == "masked" ]; then
        echo "✅ $target is masked."
    else
        echo "❌ $target is NOT masked (current state: $state)."
        FAILED=1
    fi
done

# Check logind config
LOGIND_CONF="/etc/systemd/logind.conf.d/lockdown.conf"
if [ -f "$LOGIND_CONF" ]; then
    echo "✅ Logind drop-in configuration exists at $LOGIND_CONF."
    
    # Check for specific keys
    if grep -q "HandlePowerKey=reboot" "$LOGIND_CONF"; then
        echo "✅ HandlePowerKey=reboot is set."
    else
        echo "❌ HandlePowerKey=reboot is MISSING."
        FAILED=1
    fi
else
    echo "❌ Logind drop-in configuration MISSING at $LOGIND_CONF."
    FAILED=1
fi

if [ "$FAILED" -eq 1 ]; then
    echo "Verification FAILED."
    exit 1
else
    echo "Verification PASSED."
    exit 0
fi
