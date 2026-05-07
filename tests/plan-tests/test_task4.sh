#!/bin/bash
if grep -q "path: \"/home/{{ item }}/.bashrc\"" roles/abm-post-install/tasks/add-kube-ps1.yml; then
    echo "FAIL: Still modifying individual user bashrc files."
    exit 1
fi
echo "PASS"
