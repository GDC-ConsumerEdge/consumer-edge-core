#!/bin/bash

# Test: Generation of context using a secrets companion file
# This test verifies that the companion file is read and its secrets are pushed to GSM without prompting.

set -e

# ARRANGE
cd "${TMP_ROOT}"

CONTEXT_NAME="test-sec"
CONFIG_FILE="configs/${CONTEXT_NAME}-context.yaml"
SECRETS_FILE="configs/${CONTEXT_NAME}-context-secrets.yaml"

# Create test configs from templates
cp templates/context-config-template.yaml "${CONFIG_FILE}"
cp templates/context-config-secrets-template.yaml "${SECRETS_FILE}"

# Customize the main config
yq e -i ".context_name = \"${CONTEXT_NAME}\"" "${CONFIG_FILE}"
yq e -i ".cluster_name = \"test-sec-cluster\"" "${CONFIG_FILE}"
yq e -i ".project_id = \"test-project-123\"" "${CONFIG_FILE}"

# Mock gcloud to track GSM secret additions
MOCK_LOG="${TMP_ROOT}/gcloud_mock.log"
rm -f "$MOCK_LOG"

function gcloud() {
    if [[ "$*" == "config get-value project" ]]; then
        echo "test-project-123"
        return 0
    fi
    
    # Track secret pushes
    if [[ "$*" == *"secrets versions add"* ]]; then
        local sec_name=$(echo "$*" | sed -n 's/.*secrets versions add \([^ ]*\) .*/\1/p')
        echo "PUSHED_VERSION: $sec_name" >> "$MOCK_LOG"
        # Store state in a temp file so we can retrieve it
        echo "dummy-data" > "${TMP_ROOT}/mock_secret_${sec_name}"
        return 0
    fi
    
    if [[ "$*" == *"secrets create"* ]]; then
        local sec_name=$(echo "$*" | sed -n 's/.*secrets create \([^ ]*\) .*/\1/p')
        echo "CREATED_SECRET: $sec_name" >> "$MOCK_LOG"
        return 0
    fi
    
    # Simulate that secrets describe works
    if [[ "$*" == *"secrets describe"* ]]; then
        local sec_name=$(echo "$*" | sed -n 's/.*secrets describe \([^ ]*\) .*/\1/p')
        if [[ -f "${TMP_ROOT}/mock_secret_${sec_name}" ]]; then
            return 0
        else
            return 1 # Doesn't exist yet
        fi
    fi

    # Handle secret retrieval
    if [[ "$*" == *"secrets versions access latest"* ]]; then
        local sec_name=$(echo "$*" | sed -n 's/.*--secret=\([^ ]*\) .*/\1/p')
        if [[ -f "${TMP_ROOT}/mock_secret_${sec_name}" ]]; then
            cat "${TMP_ROOT}/mock_secret_${sec_name}"
            return 0
        else
            return 1
        fi
    fi

    # Fallback
    return 0
}
export -f gcloud
export MOCK_LOG

# ACT
# Run generation. We DO NOT use echo "y" because there should be NO prompts.
# We DO NOT set GSM_SKIP_VALIDATION because we WANT the secrets validation to run (and pass because of the file).
./scripts/instance-context.sh -g "${CONTEXT_NAME}"

# ASSERT
TARGET_DIR="build-artifacts-${CONTEXT_NAME}"

if [[ ! -d "${TARGET_DIR}" ]]; then
    echo "FAIL: Target directory ${TARGET_DIR} was not created"
    exit 1
fi

# Assert that all 8 secrets were pushed
EXPECTED_SECRETS=(
    "gdc-test-sec-cluster-scm-user"
    "gdc-test-sec-cluster-scm-token"
    "gdc-test-sec-cluster-prov-gsa"
    "gdc-test-sec-cluster-node-gsa"
    "gdc-test-sec-cluster-ssh-key"
    "gdc-test-sec-cluster-ssh-key-pub"
    "gdc-test-sec-cluster-oidc-id"
    "gdc-test-sec-cluster-oidc-secret"
)

if [[ ! -f "$MOCK_LOG" ]]; then
    echo "FAIL: gcloud mock log was not created."
    exit 1
fi

for secret in "${EXPECTED_SECRETS[@]}"; do
    if ! grep -q "PUSHED_VERSION: $secret" "$MOCK_LOG"; then
        echo "FAIL: Expected secret $secret was not pushed to GSM."
        cat "$MOCK_LOG"
        exit 1
    fi
done

echo "All secrets generation assertions passed!"
