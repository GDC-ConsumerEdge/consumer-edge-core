#!/bin/bash

# Test: Generation of context from name
# One test = One user action + One outcome.

set -e

# ARRANGE
cd "${TMP_ROOT}"

CONTEXT_NAME="test-cluster"
CONFIG_FILE="configs/${CONTEXT_NAME}-context.yaml"

# Create a test config from template
cp templates/context-config-template.yaml "${CONFIG_FILE}"

# Customize the config for verification
yq e -i ".context_name = \"${CONTEXT_NAME}\"" "${CONFIG_FILE}"
yq e -i ".cluster_name = \"test-cluster-display\"" "${CONFIG_FILE}"
yq e -i ".project_id = \"test-project-123\"" "${CONFIG_FILE}"
yq e -i ".region = \"us-west1\"" "${CONFIG_FILE}"
yq e -i ".nodes = [{\"name\": \"node-a\", \"ip\": \"10.0.0.1\"}, {\"name\": \"node-b\", \"ip\": \"10.0.0.2\"}]" "${CONFIG_FILE}"
yq e -i ".abm_version = \"1.2.3.4\"" "${CONFIG_FILE}"

# Mock gcloud
function gcloud() {
    if [[ "$*" == "config get-value project" ]]; then
        echo "test-project-123"
        return 0
    fi
    
    # Store pushed secrets in a temp file so gsm_get can find them
    if [[ "$*" == *"secrets versions add"* ]]; then
        local sec_name=$(echo "$*" | sed -n 's/.*secrets versions add \([^ ]*\) .*/\1/p')
        echo "dummy-data" > "${TMP_ROOT}/mock_secret_${sec_name}"
        return 0
    fi
    
    if [[ "$*" == *"secrets create"* ]]; then
        return 0
    fi
    
    if [[ "$*" == *"secrets describe"* ]]; then
        local sec_name=$(echo "$*" | sed -n 's/.*secrets describe \([^ ]*\) .*/\1/p')
        if [[ -f "${TMP_ROOT}/mock_secret_${sec_name}" ]]; then
            return 0
        else
            return 1
        fi
    fi

    if [[ "$*" == *"secrets versions access latest"* ]]; then
        local sec_name=$(echo "$*" | sed -n 's/.*--secret=\([^ ]*\) .*/\1/p')
        if [[ -f "${TMP_ROOT}/mock_secret_${sec_name}" ]]; then
            cat "${TMP_ROOT}/mock_secret_${sec_name}"
            return 0
        else
            return 1
        fi
    fi

    return 0
}
export -f gcloud

# ACT
# Run the script without GSM_SKIP_VALIDATION. We expect it to fail fast.
OUTPUT=$(./scripts/instance-context.sh -g "${CONTEXT_NAME}" 2>&1 || true)

# ASSERT
# Directory should NOT be created because of fail-fast
TARGET_DIR="build-artifacts-${CONTEXT_NAME}"
if [[ -f "${TARGET_DIR}/ssh-config" ]]; then
    echo "FAIL: Target files were created despite missing SCM secrets"
    exit 1
fi

# Assert the correct error messages are printed
if ! echo "$OUTPUT" | grep -q "STOP: Required secret 'gdc-test-cluster-display-scm-user' is missing in GSM"; then
    echo "FAIL: Expected SCM User error message not found in output."
    echo "Output: $OUTPUT"
    exit 1
fi

if ! echo "$OUTPUT" | grep -q "STOP: Required secret 'gdc-test-cluster-display-scm-token' is missing in GSM"; then
    echo "FAIL: Expected SCM Token error message not found in output."
    echo "Output: $OUTPUT"
    exit 1
fi

# Test failure case: missing config
# Note: we need to redirect stderr to check the message
if ./scripts/instance-context.sh -g non-existent 2>&1 | grep -q "Error: File path 'configs/non-existent-context.yaml' does not exist"; then
    echo "PASS: Handled missing config correctly"
else
    echo "FAIL: Did not handle missing config correctly"
    exit 1
fi

echo "All generation assertions passed!"
