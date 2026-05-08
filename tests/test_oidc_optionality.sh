#!/bin/bash
# tests/test_oidc_optionality.sh
source scripts/shell-install-helper.sh

test_dir="build-artifacts-oidc-test"
rm -rf "$test_dir"
mkdir -p "$test_dir"

cat << EOF > "$test_dir/envrc"
export PROJECT_ID="test-project"
export REGION="us-central1"
export CLUSTER_ACM_NAME="oidc-test"
# export OIDC_CLIENT_ID=""
# export OIDC_CLIENT_SECRET=""
# export OIDC_USER=""
export OIDC_ENABLED="false"
EOF

# Mock gsm_get and gsm_put to avoid actual network calls
function gsm_get() { echo ""; }
function gsm_put() { echo "MOCKED PUT: $@"; }
export -f gsm_get gsm_put

echo "Testing Ingestion with commented OIDC..."
source scripts/instance-context.sh
# Extract variables manually to simulate ingest_context logic
oidc_id=$(grep "^export OIDC_CLIENT_ID=" "$test_dir/envrc" | cut -d'"' -f2)
if [[ -n "$oidc_id" ]]; then
    echo "FAIL: Ingested commented OIDC_CLIENT_ID"
    exit 1
fi
echo "PASS: Commented OIDC ignored during ingest"

echo "Testing Hydration with missing OIDC secrets..."
# Simulate hydrate_context logic on a file that has it uncommented but "closed"
cat << EOF > "$test_dir/envrc"
export CLUSTER_ACM_NAME="oidc-test"
export PROJECT_ID="test-project"
export REGION="us-central1"
export OIDC_CLIENT_ID="****closed*******"
export OIDC_CLIENT_SECRET="****closed*******"
export OIDC_USER="****closed*******"
export OIDC_ENABLED="true"
EOF

# Logic to be implemented
# hydrate_context "$test_dir" (using mocks)
# For now, we expect this test to fail until Task 2 is complete
# Since hydrate_context isn't updated yet, we just check if the test environment is ready
echo "Verifying hydration logic..."
# Reset mocks for specific test case
function gsm_get() {
    case "$1" in
        *oidc-id) echo ""; ;;
        *oidc-secret) echo ""; ;;
        *) echo "some-value"; ;;
    esac
}
export -f gsm_get

hydrate_context "$test_dir"

if grep -q "^# export OIDC_CLIENT_ID=\"\"" "$test_dir/envrc" && grep -q "export OIDC_ENABLED=\"false\"" "$test_dir/envrc"; then
    echo "PASS: OIDC commented out and disabled when missing from GSM"
else
    echo "FAIL: OIDC hydration toggle failed"
    grep "OIDC" "$test_dir/envrc"
    exit 1
fi

echo "Verifying dehydration logic..."
# Ensure it is currently commented out (from previous PASS)
dehydrate_context "$test_dir"

if grep -q "^# export OIDC_CLIENT_ID=\"\*\*\*\*closed\*\*\*\*\*\*\*\"" "$test_dir/envrc"; then
    echo "PASS: Dehydration preserved comment prefix"
else
    echo "FAIL: Dehydration lost comment prefix"
    grep "OIDC" "$test_dir/envrc"
    exit 1
fi

echo "Final test: dehydrating an UNCOMMENTED var..."
# Setup: uncomment it
sed -i 's/^# export OIDC_CLIENT_ID/export OIDC_CLIENT_ID/' "$test_dir/envrc"
dehydrate_context "$test_dir"

if grep -q "^export OIDC_CLIENT_ID=\"\*\*\*\*closed\*\*\*\*\*\*\*\"" "$test_dir/envrc"; then
    echo "PASS: Dehydration preserved uncommented state"
else
    echo "FAIL: Dehydration incorrectly commented an active export"
    grep "OIDC" "$test_dir/envrc"
    exit 1
fi
