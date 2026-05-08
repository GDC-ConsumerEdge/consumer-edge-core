#!/bin/bash

# Integration Test: Real GSM Interaction
# This test verifies that the script can successfully communicate with Google Secret Manager.

set -e

# Check for a valid GCP project
PROJECT_ID=$(gcloud config get-value project 2>/dev/null || true)
if [[ -z "$PROJECT_ID" || "$PROJECT_ID" == "(unset)" ]]; then
    echo "SKIP: No default gcloud project found. Skipping GSM integration test."
    exit 0
fi

cd "${TMP_ROOT}"

# Generate an 8-digit random suffix to prevent GSM name collisions
SUFFIX=$(LC_ALL=C tr -dc '0-9' < /dev/urandom | head -c 8)
CONTEXT_NAME="test-int-${SUFFIX}"
SECRET_NAME="context-${CONTEXT_NAME}"

echo "Integration testing with context: ${CONTEXT_NAME} in project ${PROJECT_ID}"

# Cleanup function to ensure the secret is removed after the test
function cleanup_gsm() {
    echo "Cleaning up GSM secret: ${SECRET_NAME}"
    gcloud secrets delete "${SECRET_NAME}" --project="${PROJECT_ID}" --quiet 2>/dev/null || true
}

# Ensure cleanup runs on exit (success or failure)
trap cleanup_gsm EXIT

# ACT: Create context and sync to GSM
# Provide 'y' to the sync prompt, and optionally provide PROJECT_ID if prompted
./scripts/instance-context.sh -c "${CONTEXT_NAME}" << EOF
y
EOF

# ASSERT: Verify secret exists in GSM
# We call the real gcloud command here to verify the secret was created
if ! gcloud secrets describe "${SECRET_NAME}" --project="${PROJECT_ID}" &>/dev/null; then
    echo "FAIL: Secret ${SECRET_NAME} was not created in GSM."
    exit 1
fi

echo "PASS: Secret ${SECRET_NAME} successfully created and verified in GSM."
