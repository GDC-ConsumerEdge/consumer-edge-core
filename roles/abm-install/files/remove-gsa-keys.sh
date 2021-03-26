#!/bin/bash

echo "NOTE: This will remove ALL keys for the created GSAs in the 'abm-install' task"

ACCOUNTS=("abm-cloud-operations-agent" "abm-gke-connect-agent" "abm-gke-register-agent" "abm-gcr-agent" )

# Cycle through all keys for all accounts
for account in "${ACCOUNTS[@]}"; do

    ACCOUNT_EMAIL="${account}@${PROJECT_ID}.iam.gserviceaccount.com"
    KEYS=($(gcloud iam service-accounts keys list --iam-account="${ACCOUNT_EMAIL}" --managed-by="user" --format="value(KEY_ID)" --project="${PROJECT_ID}"))
    echo "Removing keys for account [${ACCOUNT_EMAIL}]"
    for key in "${KEYS[@]}"; do
        echo "Removing [$ACCOUNT} Key '${key}'"
        gcloud iam service-accounts keys delete ${key} --iam-account=${ACCOUNT_EMAIL}  --project=${PROJECT_ID} --quiet
    done

done