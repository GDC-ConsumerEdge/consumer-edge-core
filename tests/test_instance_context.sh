#!/bin/bash

# Test if the script exists and runs help
if ! ./scripts/instance-context.sh -h | grep -q "Usage:"; then
  echo "FAIL: instance-context.sh -h did not output Usage"
  exit 1
fi
echo "PASS: Script renamed and executable"

# Test missing yq/yaml logic
if ./scripts/instance-context.sh -g non_existent.yaml 2>&1 | grep -q "not found"; then
  echo "PASS: Handled missing YAML"
else
  echo "FAIL: Did not handle missing YAML"
  exit 1
fi

# Test full generation
./scripts/instance-context.sh -g tests/sample-cluster.yaml
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
