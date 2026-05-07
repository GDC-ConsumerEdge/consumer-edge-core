#!/bin/bash
if grep -q "Remove provisioning GSA profile" roles/abm-post-install/tasks/main.yml; then
    echo "FAIL: Redundant removal task still exists"
    exit 1
fi
echo "PASS"
