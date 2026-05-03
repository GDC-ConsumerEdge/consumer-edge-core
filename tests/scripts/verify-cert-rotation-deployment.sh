#!/bin/bash
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Verification script for Certificate Rotation distributed lock deployment.
# This script logs into each node and outputs the cron schedule and script permissions.

SSH_CONFIG="build-artifacts/ssh-config"
NODES=("edge-1" "edge-2" "edge-3")
CRON_FILE="/etc/cron.d/rotate-k8s-certs-cron.sh"
SCRIPT_FILE="/var/abm-install/scripts/rotate-k8s-certs.sh"

echo "================================================================="
echo "   Verifying Certificate Rotation Cron and Script Permissions    "
echo "================================================================="

if [ ! -f "$SSH_CONFIG" ]; then
    echo "ERROR: SSH config file not found at $SSH_CONFIG"
    echo "Please run this from the root of the consumer-edge-core repository."
    exit 1
fi

for NODE in "${NODES[@]}"; do
    echo ""
    echo "------------------------------------------------"
    echo " Node: $NODE"
    echo "------------------------------------------------"
    
    # Run a block of commands over SSH
    ssh -F "$SSH_CONFIG" "$NODE" "bash -s" <<EOF
        echo "1. Crontab Settings ($CRON_FILE):"
        if [ -f "$CRON_FILE" ]; then
            cat "$CRON_FILE" | grep -v "^#"
        else
            echo "   [ERROR] Cron file not found!"
        fi
        
        echo ""
        echo "2. Script Location and Permissions ($SCRIPT_FILE):"
        if [ -f "$SCRIPT_FILE" ]; then
            ls -l "$SCRIPT_FILE"
        else
            echo "   [ERROR] Rotation script not found!"
        fi
EOF
done

echo ""
echo "================================================================="
echo " Verification Complete."
echo " - Ensure cron minutes are staggered (e.g. 0, 1, 2)."
echo " - Ensure cron schedule is 3-months (e.g. */3)."
echo " - Ensure script permissions are least-privileged (-rwx------)."
echo "================================================================="
