#!/bin/bash -e

echo "This will create a Google Service Account and key that is used on each of the Target machines to run gcloud commands"

PROJECT_ID=${1:-$PROJECT_ID}
GSA_NAME="target-machine-gsa"
GSA_EMAIL="${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
KEY_LOCATION="./build-artifacts/consumer-edge-gsa.json"

if [[ -z "${PROJECT_ID}" ]]; then
  echo "Project ID required, provide as script argument or 'export PROJECT_ID={}'"
  exit 1
fi

EXISTS=$(gcloud iam service-accounts list --filter="email=${GSA_EMAIL}" --format="value(name, disabled)" --project="${PROJECT_ID}")
if [[ -z "${EXISTS}" ]]; then
    echo "GSA [${GSA_EMAIL}]does not exist, creating it"
    # GSA does NOT exist, create
    gcloud iam service-accounts create ${GSA_NAME} \
        --description="GSA used on each Target machine to make gcloud commands" \
        --display-name="target-machine-gsa" \
        --project ${PROJECT_ID}
else
    if [[ "$EXISTS" =~ .*"disabled".* ]]; then
        # Found GSA is disabled, enable
        gcloud iam service-accounts enable ${GSA_EMAIL} --project ${PROJECT_ID}
    fi
    # otherwise, no need to do anything
fi

# Bootstrap a few API services:
gcloud services enable servicemanagement.googleapis.com compute.googleapis.com secretmanager.googleapis.com containerregistry.googleapis.com serviceusage.googleapis.com compute.googleapis.com secretmanager.googleapis.com sourcerepo.googleapis.com --project ${PROJECT_ID}

echo "Adding roles/editor"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${GSA_EMAIL}" \
    --role="roles/editor" --no-user-output-enabled

echo "Adding roles/storage.objectViewer"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${GSA_EMAIL}" \
    --role="roles/storage.objectViewer" --no-user-output-enabled

echo "Adding roles/resourcemanager.projectIamAdmin"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${GSA_EMAIL}" \
    --role="roles/resourcemanager.projectIamAdmin" --no-user-output-enabled

echo "Adding roles/secretmanager.admin"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${GSA_EMAIL}" \
    --role="roles/secretmanager.admin" --no-user-output-enabled

echo "Adding roles/secretmanager.secretAccessor"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${GSA_EMAIL}" \
    --role="roles/secretmanager.secretAccessor" --no-user-output-enabled

echo "Adding roles/gkehub.gatewayAdmin"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${GSA_EMAIL}" \
    --role="roles/gkehub.gatewayAdmin" --no-user-output-enabled

echo "Adding roles/gkehub.viewer"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${GSA_EMAIL}" \
    --role="roles/gkehub.viewer" --no-user-output-enabled

# We should have a GSA enabled or created or ready-to-go by here

echo -e "\n====================\n"

read -r -p "Create a new key for GSA? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    gcloud iam service-accounts keys create ${KEY_LOCATION} \
        --iam-account=${GSA_EMAIL} \
        --project ${PROJECT_ID}

    # reducing OS visibility to read-only for current user
    chmod 400 ${KEY_LOCATION}
else
    echo "Skipping making new keys"
fi
