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

TMP_DIR=$(mktemp -d -t "cert-rotation-test-XXXXXX")
echo "Capturing node outputs to: $TMP_DIR"
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
    
    # Run the rotation command in the background, redirecting stdout/stderr to a log file
    ssh -F "$SSH_CONFIG" "$NODE" "sudo runuser -l 'abm-admin' -c '${SCRIPT_PATH}'" > "${TMP_DIR}/${NODE}.log" 2>&1 &
done

echo ""
echo "All nodes triggered. Waiting for all processes to complete (this will take ~5 minutes due to the built-in sleep)..."
wait
echo "All triggered processes have completed."
echo ""
echo "================================================================="
echo "   Verification Results                                          "
echo "================================================================="

ACQUIRED_COUNT=0
ABORTED_COUNT=0

for NODE in "${NODES[@]}"; do
    LOG_FILE="${TMP_DIR}/${NODE}.log"
    if grep -q "Lock acquired successfully" "$LOG_FILE"; then
        echo "[${NODE}] SUCCESS: Acquired lock and performed rotation."
        ACQUIRED_COUNT=$((ACQUIRED_COUNT + 1))
    elif grep -q "ABORT: Lock held by another node" "$LOG_FILE"; then
        echo "[${NODE}] ABORTED: Correctly identified lock was already held."
        ABORTED_COUNT=$((ABORTED_COUNT + 1))
    else
        echo "[${NODE}] UNKNOWN STATE. See log for details: $LOG_FILE"
        # Print a snippet of the log for debugging
        tail -n 5 "$LOG_FILE" | sed 's/^/    > /'
    fi
done

echo ""
if [ "$ACQUIRED_COUNT" -eq 1 ] && [ "$ABORTED_COUNT" -eq 2 ]; then
    echo "✅ PASS: Exactly one node acquired the lock, and two nodes aborted."
else
    echo "❌ FAIL: Expected 1 lock acquisition and 2 aborts. Got $ACQUIRED_COUNT acquisitions and $ABORTED_COUNT aborts."
fi

echo ""
echo "Checking GCS for lingering lock files..."
# We run the check from edge-1 since it has gcloud configured and authenticated.
# We dynamically pull the LOCK_URI from the deployed script itself.
LOCK_URI=$(ssh -F "$SSH_CONFIG" "${NODES[0]}" "grep '^LOCK_URI=' $SCRIPT_PATH | cut -d'\"' -f2")

if [ -z "$LOCK_URI" ]; then
    echo "⚠️ WARNING: Could not determine LOCK_URI from $SCRIPT_PATH on ${NODES[0]}."
else
    echo "Target Lock URI: $LOCK_URI"
    if ssh -F "$SSH_CONFIG" "${NODES[0]}" "gcloud storage ls '$LOCK_URI'" > /dev/null 2>&1; then
        echo "❌ FAIL: Lock file still exists in GCS! Cleanup trap may have failed."
    else
        echo "✅ PASS: Lock file was successfully cleaned up from GCS."
    fi
fi

echo "================================================================="
echo "Test logs preserved in: $TMP_DIR"
