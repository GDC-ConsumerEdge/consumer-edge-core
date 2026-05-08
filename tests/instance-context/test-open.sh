#!/bin/bash

# Test: Opening a context and verifying key formatting
# This test verifies that the hydrate_context ('open') function writes the
# consumer-edge-machine private key with exactly one trailing newline.

set -e

# ARRANGE
cd "${TMP_ROOT}"

CONTEXT_NAME="test-open"
TARGET_DIR="build-artifacts-${CONTEXT_NAME}"
mkdir -p "${TARGET_DIR}"

# Create a mock envrc so hydration knows which project/cluster to target
cat << EOF > "${TARGET_DIR}/envrc"
export CLUSTER_ACM_NAME="mock-cluster"
export PROJECT_ID="mock-project"
export REGION="us-central1"
EOF

# Link it as the active build-artifacts context, simulating a switch
rm -f build-artifacts
ln -s "${TARGET_DIR}" build-artifacts

# Mock gcloud to return a key WITH no trailing newline to test if trim_key_file fixes it
# It could also return one with multiple newlines. Let's return one with NO newlines.
function gcloud() {
    if [[ "$*" == *"secrets versions access latest"* ]]; then
        local sec_name=$(echo "$*" | sed -n 's/.*--secret=\([^ ]*\) .*/\1/p')
        if [[ "$sec_name" == "gdc-mock-cluster-ssh-key" ]]; then
            # Return a key with NO trailing newline
            echo -n "-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
-----END OPENSSH PRIVATE KEY-----"
            return 0
        fi
        
        # Provide dummy values for all other required secrets to avoid prompts
        echo "dummy-value-for-${sec_name}"
        return 0
    fi
    return 0
}
export -f gcloud

# ACT
# Run 'open' command (hydrate_context)
# It should pull the key from the mock and write it.
./scripts/instance-context.sh -o

# ASSERT Key Formatting
KEY_FILE="build-artifacts/consumer-edge-machine"
if [[ ! -f "$KEY_FILE" ]]; then
    echo "FAIL: $KEY_FILE was not created during open"
    exit 1
fi

LAST_LINE=$(cat -e "$KEY_FILE" | tail -n 1)
if [[ "$LAST_LINE" != "-----END OPENSSH PRIVATE KEY-----\$" ]]; then
    echo "FAIL: Key file does not end with exactly one newline."
    exit 1
fi

# TEST CASE: YAML Conflict - Option 2 (Upload local to GSM)
echo "Testing YAML Conflict - Option 2 (Upload)..."
mkdir -p configs
LOCAL_YAML="configs/${CONTEXT_NAME}-context.yaml"
echo "local-content-different-than-gsm" > "$LOCAL_YAML"

# We need a new mock that tracks secret additions specifically for the YAML
MOCK_LOG="${TMP_ROOT}/gsm_upload_test.log"
rm -f "$MOCK_LOG"

function gcloud() {
    if [[ "$*" == *"secrets versions access latest"* ]]; then
        echo "gsm-content"
        return 0
    fi
    if [[ "$*" == *"secrets versions add"* ]]; then
        echo "$*" >> "${TMP_ROOT}/gsm_upload_test.log"
        return 0
    fi
    return 0
}
export -f gcloud

# Run hydration and choose option 2
echo "2" | ./scripts/instance-context.sh -o

if ! grep -q "context-${CONTEXT_NAME}" "${TMP_ROOT}/gsm_upload_test.log"; then
    echo "FAIL: Local YAML was not uploaded to GSM after choosing option 2"
    exit 1
fi

echo "PASS: consumer-edge-machine formatting and YAML sync options verified."
