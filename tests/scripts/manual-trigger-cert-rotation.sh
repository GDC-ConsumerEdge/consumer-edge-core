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

# Script to manually trigger certificate rotation across all nodes in the cluster.
# This script staggers the execution by 30 seconds to test the coordination 
# and locking mechanism.

SSH_CONFIG="build-artifacts/ssh-config"
NODES=("edge-1" "edge-2" "edge-3")
SCRIPT_PATH="/var/abm-install/scripts/rotate-k8s-certs.sh"
STAGGER_SECONDS=30

echo "================================================================="
echo "   Manually Triggering Certificate Rotation (Staggered)          "
echo "================================================================="

if [ ! -f "$SSH_CONFIG" ]; then
    echo "ERROR: SSH config file not found at $SSH_CONFIG"
    exit 1
fi

for i in "${!NODES[@]}"; do
    NODE="${NODES[$i]}"
    
    # Don't sleep before the first node
    if [ "$i" -gt 0 ]; then
        echo "Waiting ${STAGGER_SECONDS}s before triggering next node..."
        sleep $STAGGER_SECONDS
    fi

    echo "[$(date +%T)] Triggering rotation on ${NODE}..."
    
    # Run the rotation command in the background so the script continues to stagger
    ssh -F "$SSH_CONFIG" "$NODE" "sudo runuser -l 'abm-admin' -c '${SCRIPT_PATH}'" &
done

echo ""
echo "All nodes triggered. The commands are running in the background."
echo "Check /var/abm-install/scripts/rotate-certs.log on each node for details."
echo "================================================================="

# Wait for background processes to finish if you want to see the final exit statuses
wait
echo "All triggered processes have completed."
