#!/usr/bin/env bash

set -e

echo "This will create a Google Service Account and key that is used on each of the target machines to run gcloud commands"

PROJECT_ID=${1:-${PROJECT_ID}}
PROVISIONING_GSA_NAME="provision-gsa"
PROVISIONING_GSA="${PROVISIONING_GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
NODE_GSA_NAME="node-gsa"
NODE_GSA="${NODE_GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
PROVISIONING_KEY_LOCATION="./build-artifacts/provisioning-gsa.json"
NODE_KEY_LOCATION="./build-artifacts/node-gsa.json"

KMS_KEY_NAME="gdc-ssh-key"
KMS_KEYRING_NAME="gdc-ce-keyring"
KMS_KEYRING_LOCATION=${2-"global"}

if [[ -z "${PROJECT_ID}" ]]; then
  echo "Project ID required, provide as script argument or 'export PROJECT_ID={}'"
  exit 1
fi

# Provisioning GSA
PROV_EXISTS=$(gcloud iam service-accounts list \
  --filter="email=${PROVISIONING_GSA}" \
  --format="value(name, disabled)" \
  --project="${PROJECT_ID}")

if [[ -z "${PROV_EXISTS}" ]]; then
  echo "GSA [${PROVISIONING_GSA}]does not exist, creating it"

  # GSA does NOT exist, create
  gcloud iam service-accounts create ${PROVISIONING_GSA_NAME} \
    --description="GSA used during provisioning with gcloud commands" \
    --display-name="${PROVISIOING_GSA_NAME}" \
    --project ${PROJECT_ID}
else
  if [[ "${PROV_EXISTS}" =~ .*"disabled".* ]]; then
    # Found GSA is disabled, enable
    gcloud iam service-accounts enable ${PROVISIONING_GSA} --project ${PROJECT_ID}
  fi
  # otherwise, no need to do anything
fi

# Node GSA
NODE_EXISTS=$(gcloud iam service-accounts list \
  --filter="email=${NODE_GSA}" \
  --format="value(name, disabled)" \
  --project="${PROJECT_ID}")

if [[ -z "${NODE_EXISTS}" ]]; then
  echo "GSA [${NODE_GSA}]does not exist, creating it"

  # GSA does NOT exist, create
  gcloud iam service-accounts create ${NODE_GSA_NAME} \
    --description="GSA which persists on each node" \
    --display-name="${NODE_GSA_NAME}" \
    --project ${PROJECT_ID}
else
  if [[ "${NODE_EXISTS}" =~ .*"disabled".* ]]; then
    # Found GSA is disabled, enable
    gcloud iam service-accounts enable ${NODE_GSA} --project ${PROJECT_ID}
  fi
  # otherwise, no need to do anything
fi

# FIXME: These are not specific to GSA creation, but necessary for project
# setup (future, this will all be terraform)
gcloud services enable --project ${PROJECT_ID} \
  cloudkms.googleapis.com \
  compute.googleapis.com \
  containerregistry.googleapis.com \
  secretmanager.googleapis.com \
  servicemanagement.googleapis.com \
  serviceusage.googleapis.com \
  sourcerepo.googleapis.com

### Create Keyring for SSH key encryption (future terraform) -- Keyring and
# keys are used to encrypt/decrypt SSH keys on the provisioning system during
# provisioning (target host has the pub-key matching encrypted private key)
HAS_KEYRING=$(gcloud kms keyrings list \
  --location="${KMS_KEYRING_LOCATION}" \
  --format="value(name)" \
  --filter="name~${KMS_KEYRING_NAME}" \
  --project "${PROJECT_ID}")

if [[ -z "${HAS_KEYRING}" ]]; then
  gcloud kms keyrings create "${KMS_KEYRING_NAME}" \
    --location="${KMS_KEYRING_LOCATION}" \
    --project "${PROJECT_ID}"
fi

### Check to see if key exists, create if not
HAS_KEY=$(gcloud kms keys list \
  --location="${KMS_KEYRING_LOCATION}" \
  --keyring="${KMS_KEYRING_NAME}" \
  --format="value(name)" \
  --project "${PROJECT_ID}")

if [[ -z "${HAS_KEY}" ]]; then
  gcloud kms keys create "${KMS_KEY_NAME}" \
    --keyring "${KMS_KEYRING_NAME}" \
    --location "${KMS_KEYRING_LOCATION}" \
    --purpose "encryption" \
    --project "${PROJECT_ID}"
fi

### Set roles for GSA
declare -a ROLES=(
  "roles/viewer"
  "roles/monitoring.editor"
  "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  "roles/gkehub.gatewayAdmin"
  "roles/gkehub.viewer"
  "roles/resourcemanager.projectIamAdmin"
  "roles/secretmanager.admin"
  "roles/secretmanager.secretAccessor"
  "roles/storage.admin"
  "roles/iam.serviceAccountAdmin"
  "roles/iam.serviceAccountKeyAdmin"
)

for role in ${ROLES[@]}; do
  echo "Adding ${role}"
  gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${PROVISIONING_GSA}" \
    --role="${role}" \
    --no-user-output-enabled
done

# We should have a GSA enabled or created or ready-to-go by here

echo -e "\n====================\n"

read -r -p "Create a new key for GSA? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  gcloud iam service-accounts keys create ${PROVISIONING_KEY_LOCATION} \
    --iam-account=${PROVISIONING_GSA} \
    --project ${PROJECT_ID}

  # reducing OS visibility to read-only for current user
  chmod 400 ${PROVISIONING_KEY_LOCATION}

  gcloud iam service-accounts keys create ${NODE_KEY_LOCATION} \
    --iam-account=${NODE_GSA} \
    --project ${PROJECT_ID}

  # reducing OS visibility to read-only for current user
  chmod 400 ${NODE_KEY_LOCATION}
else
  echo "Skipping making new keys"
fi
