#!/bin/bash
if grep -q "runuser -l" roles/ready-linux/templates/gcloud-update-cron.j2; then
    echo "FAIL: Cron job still forces a login shell using -l."
    exit 1
fi
echo "PASS"
