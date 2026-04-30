#!/bin/bash

# Test if the script exists and runs help
if ! ./scripts/instance-context.sh -h | grep -q "Usage:"; then
  echo "FAIL: instance-context.sh -h did not output Usage"
  exit 1
fi
echo "PASS: Script renamed and executable"
