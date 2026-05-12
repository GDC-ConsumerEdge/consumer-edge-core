#!/bin/bash

# Test if the script exists and runs help
if ! ./scripts/instance-context.sh -h 2>&1 | grep -q "Usage:"; then
  echo "FAIL: instance-context.sh -h did not output Usage"
  exit 1
fi
echo "PASS: Script renamed and executable"

# Test missing yq/yaml logic
if echo "" | ./scripts/instance-context.sh -g non_existent 2>&1 | grep -q "does not exist"; then
  echo "PASS: Handled missing YAML"
else
  echo "FAIL: Did not handle missing YAML"
  exit 1
fi

# Test full generation
GSM_SKIP_VALIDATION="true" ./scripts/instance-context.sh -g tests/sample-cluster.yaml << 'EOF'
y
EOF

if [[ -d "build-artifacts-test-cluster" ]]; then
  if grep -q "test-gcp-project" build-artifacts-test-cluster/envrc; then
    echo "PASS: Context generated successfully"
    rm -rf build-artifacts-test-cluster
  else
    echo "FAIL: envrc not templated correctly"
    exit 1
  fi
else
  echo "FAIL: Context directory not created"
  exit 1
fi

# Test trim_key_file function
echo "Testing trim_key_file..."
source scripts/shell-install-helper.sh

# Case 1: Trailing spaces and multiple newlines
cat << 'INNER_EOF' > test_key.txt
test-key  
line 2   


INNER_EOF
trim_key_file test_key.txt
cat -e test_key.txt > test_key_out.txt
if ! grep -q 'line 2\$' test_key_out.txt; then
    echo "FAIL: trim_key_file failed to trim trailing spaces or add newline"
    cat test_key_out.txt
    exit 1
fi
rm test_key.txt test_key_out.txt
echo "PASS: trim_key_file works as expected"
