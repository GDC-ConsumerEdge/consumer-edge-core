#!/bin/bash

# Test: Closing a context and verifying SSH agent eviction
# This test verifies that dehydrate_context ('close') attempts to remove the
# private key from the ssh-agent.

set -e

# ARRANGE
cd "${TMP_ROOT}"

CONTEXT_NAME="test-close"
TARGET_DIR="build-artifacts-${CONTEXT_NAME}"
mkdir -p "${TARGET_DIR}"

# Create a dummy private key file
KEY_FILE="${TARGET_DIR}/consumer-edge-machine"
echo "dummy-private-key" > "$KEY_FILE"

# Mock ssh-add to track the deletion call
MOCK_LOG="${TMP_ROOT}/ssh_agent_mock.log"
rm -f "$MOCK_LOG"

function ssh-add() {
    echo "SSH_ADD_CALLED: $*" >> "${TMP_ROOT}/ssh_agent_mock.log"
    return 0
}
export -f ssh-add

# ACT
# Run 'close' action
./scripts/instance-context.sh -x "${CONTEXT_NAME}"

# ASSERT
if [[ ! -f "$MOCK_LOG" ]]; then
    echo "FAIL: ssh-add was not called during close"
    exit 1
fi

# Verify the deletion flag (-d) was used with the correct file path
if ! grep -q "SSH_ADD_CALLED: -d ${TARGET_DIR}/consumer-edge-machine" "$MOCK_LOG"; then
    echo "FAIL: ssh-add -d was not called for the private key"
    cat "$MOCK_LOG"
    exit 1
fi

# Verify files were also removed from disk
if [[ -f "$KEY_FILE" ]]; then
    echo "FAIL: Private key file was not removed from disk"
    exit 1
fi

echo "PASS: SSH agent eviction and disk cleanup verified successfully."
