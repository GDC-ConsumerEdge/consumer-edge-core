#!/bin/bash
# tests/test_validation.sh
source scripts/shell-install-helper.sh

test_dir="build-artifacts-validation-test"
# Ensure we start clean
rm -rf "$test_dir" configs/validation-test-context.yaml configs/validation-test-context-secrets.yaml

# Create a mock gcloud to avoid hanging on GSM calls
mkdir -p mock_bin
cat << 'EOF' > mock_bin/gcloud
#!/bin/bash
# Return 1 to simulate "not found" or "failure" which triggers fallback logic in script
exit 1
EOF
chmod +x mock_bin/gcloud
ORIG_PATH="$PATH"
export PATH="$(pwd)/mock_bin:$PATH"

echo "--------------------------------------------------"
echo "Running test: YAML and JSON Validation"

# 1. Test YAML Validation during generate
echo "Testing invalid YAML in generate..."
mkdir -p configs
cat << 'EOF' > configs/validation-test-context.yaml
context_name: "validation-test"
cluster_name: "test-cluster"
project_id: "test-project"
invalid_yaml: {
  unclosed_brace: "value"
EOF

# Pipe 'n' to skip secret file creation prompt
output=$(./scripts/instance-context.sh -g validation-test 2>&1 << 'EOF'
n
EOF
)
if echo "$output" | grep -q "Invalid YAML format"; then
    echo "PASS: Invalid YAML detected during generate"
else
    echo "FAIL: Invalid YAML not detected"
    echo "$output"
    export PATH="$ORIG_PATH"
    exit 1
fi

# 2. Setup valid context for JSON tests
echo "Setting up valid context..."
cp templates/context-config-template.yaml configs/validation-test-context.yaml
sed -i 's/context_name: "my-cluster-context"/context_name: "validation-test"/' configs/validation-test-context.yaml
sed -i 's/project_id: "your-gcp-project-id"/project_id: "test-project"/' configs/validation-test-context.yaml

# Create a secrets file to avoid ALL interactive prompts
# Note: the script expects configs/context-<name>-secrets.yaml
cat << 'EOF' > configs/context-validation-test-secrets.yaml
ssh_key: "dummy-key"
ssh_pub_key: "dummy-pub-key"
prov_gsa: '{"valid": "json"}'
node_gsa: '{"valid": "json"}'
scm_user: "dummy-user"
scm_token: "dummy-token"
EOF

# Generate the context folder (Closed state)
# Provide 'n' to skip secrets file creation prompt
GSM_SKIP_VALIDATION="true" ./scripts/instance-context.sh -g validation-test > /dev/null 2>&1 << 'EOF'
n
EOF

if [[ ! -d "$test_dir" ]]; then
    echo "FAIL: Setup failed, context directory '$test_dir' not created"
    export PATH="$ORIG_PATH"
    exit 1
fi

# 4. Test JSON Validation during hydrate (open)
echo "Testing invalid JSON in secrets file during hydrate..."
cat << 'EOF' > configs/context-validation-test-secrets.yaml
ssh_key: "dummy-key"
ssh_pub_key: "dummy-pub-key"
prov_gsa: '{ "invalid": "json" '
node_gsa: '{"valid": "json"}'
scm_user: "dummy-user"
scm_token: "dummy-token"
EOF

# This should trigger the "STOP: Invalid JSON found for Provisioning GSA." error
# Use heredoc to provide answers to ANY possible prompts (like sync prompt '3')
output=$(./scripts/instance-context.sh -o validation-test 2>&1 << 'EOF'
3
EOF
)

if echo "$output" | grep -q "Invalid JSON found for Provisioning GSA"; then
    echo "PASS: Invalid JSON detected in secrets file during hydrate"
else
    echo "FAIL: Invalid JSON not detected during hydrate"
    echo "$output"
    export PATH="$ORIG_PATH"
    exit 1
fi

# 5. Verify it also works for Node GSA
echo "Testing invalid JSON for Node GSA..."
cat << 'EOF' > configs/context-validation-test-secrets.yaml
ssh_key: "dummy-key"
ssh_pub_key: "dummy-pub-key"
prov_gsa: '{"valid": "json"}'
node_gsa: '{ "invalid": "json" '
scm_user: "dummy-user"
scm_token: "dummy-token"
EOF

output=$(./scripts/instance-context.sh -o validation-test 2>&1 << 'EOF'
3
EOF
)

if echo "$output" | grep -q "Invalid JSON found for Node GSA"; then
    echo "PASS: Invalid JSON detected for Node GSA during hydrate"
else
    echo "FAIL: Invalid JSON not detected for Node GSA"
    echo "$output"
    export PATH="$ORIG_PATH"
    exit 1
fi

# Cleanup
export PATH="$ORIG_PATH"
rm -rf "$test_dir" configs/validation-test-context.yaml configs/context-validation-test-secrets.yaml mock_bin
echo "--------------------------------------------------"
echo "PASS: All validation tests passed."
