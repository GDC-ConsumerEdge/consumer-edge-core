#!/bin/bash

# Test Runner for instance-context enhancements
# Provides state isolation and executes test cases

set -e

REPO_ROOT=$(pwd)
TEST_DIR="${REPO_ROOT}/tests/instance-context"
TMP_ROOT="${REPO_ROOT}/tmp-instance-context-tests"

function cleanup() {
    echo "Cleaning up temporary test environment..."
    rm -rf "${TMP_ROOT}"
}

trap cleanup EXIT

echo "Setting up temporary test environment in ${TMP_ROOT}..."
rm -rf "${TMP_ROOT}"
mkdir -p "${TMP_ROOT}/scripts"
mkdir -p "${TMP_ROOT}/templates"
mkdir -p "${TMP_ROOT}/configs"
mkdir -p "${TMP_ROOT}/build-artifacts-example"

# Copy necessary files for the script to run
cp "${REPO_ROOT}/scripts/instance-context.sh" "${TMP_ROOT}/scripts/"
cp "${REPO_ROOT}/scripts/install-shell-helper.sh" "${TMP_ROOT}/scripts/"
cp -r "${REPO_ROOT}/templates/"* "${TMP_ROOT}/templates/"
cp "${REPO_ROOT}/build-artifacts-example/ssh-config" "${TMP_ROOT}/build-artifacts-example/"
cp "${REPO_ROOT}/build-artifacts-example/add-hosts-example" "${TMP_ROOT}/build-artifacts-example/"

# Export functions for sub-tests
export TMP_ROOT
export REPO_ROOT

# Run tests
FAILED=0
for test_script in "${TEST_DIR}"/test-*.sh; do
    if [[ -f "$test_script" ]]; then
        echo "--------------------------------------------------"
        echo "Running test: $(basename "$test_script")"
        if bash "$test_script"; then
            echo "PASS: $(basename "$test_script")"
        else
            echo "FAIL: $(basename "$test_script")"
            FAILED=1
        fi
    fi
done

if [[ $FAILED -eq 0 ]]; then
    echo "=================================================="
    echo "ALL TESTS PASSED"
    exit 0
else
    echo "=================================================="
    echo "SOME TESTS FAILED"
    exit 1
fi
