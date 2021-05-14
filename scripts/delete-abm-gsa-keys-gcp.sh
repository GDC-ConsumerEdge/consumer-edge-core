#!/bin/bash

# Remove all service account keys for the ABM GSAs from GCP

GSAs=(
    "abm-gke-register-agent@${PROJECT_ID}.iam.gserviceaccount.com"
    "abm-cloud-operations-agent@${PROJECT_ID}.iam.gserviceaccount.com"
    "abm-gcr-agent@${PROJECT_ID}.iam.gserviceaccount.com"
    "abm-gke-connect-agent@${PROJECT_ID}.iam.gserviceaccount.com"
    "external-secrets-k8s@${PROJECT_ID}.iam.gserviceaccount.com"
     )

# gcloud iam service-accounts keys create /var/keys/abm-gke-register-agent-creds.json --iam-account=abm-gke-register-agent@anthos-bare-metal-lab-1.iam.gserviceaccount.com --project=anthos-bare-metal-lab-1

for GSA in "${GSAs[@]}"
do
    KEYS=( $(gcloud iam service-accounts keys list --iam-account=$GSA --format="value(name)" --managed-by="user" --project="${PROJECT_ID}") )
    echo "Removing ${#KEYS[@]} keys for: $GSA"
    for KEY in "${KEYS[@]}"
    do
        gcloud iam service-accounts keys delete $KEY --iam-account=$GSA --quiet --project="${PROJECT_ID}"
    done
done