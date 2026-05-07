#!/bin/bash
if grep -q "Add node GSA activation script to /etc/profile.d" roles/google-tools/tasks/main.yml; then
    echo "FAIL: Old profile tasks still exist in main.yml"
    exit 1
fi

if [ ! -f "roles/google-tools/templates/01-gcloud-auth.sh.j2" ]; then
    echo "FAIL: Template 01-gcloud-auth.sh.j2 does not exist"
    exit 1
fi
echo "PASS"
