#!/bin/bash
if grep -q "Add gcloud to PATH on all shells" roles/google-tools/tasks/main.yml; then
    echo "FAIL: Redundant PATH manipulation task still exists."
    exit 1
fi
echo "PASS"
