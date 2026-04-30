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
