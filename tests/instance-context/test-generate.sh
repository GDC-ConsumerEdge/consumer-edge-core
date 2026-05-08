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
    # Secrets always missing in this mock for now
    return 1
}
export -f gcloud

# ACT
# Use echo "y" and redirect to the script
echo "y" | GSM_SKIP_VALIDATION="true" ./scripts/instance-context.sh -g "${CONTEXT_NAME}"

# ASSERT
TARGET_DIR="build-artifacts-${CONTEXT_NAME}"

if [[ ! -d "${TARGET_DIR}" ]]; then
    echo "FAIL: Target directory ${TARGET_DIR} was not created"
    exit 1
fi

# Directory check
for f in ssh-config instance-run-vars.yaml inventory.yaml envrc; do
    if [[ ! -f "${TARGET_DIR}/$f" ]]; then
        echo "FAIL: Missing file ${TARGET_DIR}/$f"
        exit 1
    fi
done

# Verify fields
if ! grep -q "export REGION=\"us-west1\"" "${TARGET_DIR}/envrc"; then
    echo "FAIL: envrc has wrong REGION"
    grep "REGION=" "${TARGET_DIR}/envrc"
    exit 1
fi

# inventory.yaml
NODE_COUNT=$(yq e ".test_cluster_display_cluster.hosts | length" "${TARGET_DIR}/inventory.yaml")
if [[ "$NODE_COUNT" != "2" ]]; then
    echo "FAIL: inventory.yaml node count is $NODE_COUNT, expected 2"
    exit 1
fi

# instance-run-vars.yaml
ABM_VER=$(yq e ".abm_version" "${TARGET_DIR}/instance-run-vars.yaml")
if [[ "$ABM_VER" != "1.2.3.4" ]]; then
    echo "FAIL: instance-run-vars.yaml abm_version is $ABM_VER, expected 1.2.3.4"
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
