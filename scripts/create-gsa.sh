#!/usr/bin/env bash
# Copyright 2023 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


set -e

echo "This will create a Google Service Account and key that is used on each of the target machines to run gcloud commands"

PROJECT_ID=${1:-${PROJECT_ID}}
PROVISIONING_GSA_NAME="provision-gsa"
PROVISIONING_GSA="${PROVISIONING_GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
NODE_GSA_NAME="node-gsa"
NODE_GSA="${NODE_GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
PROVISIONING_KEY_LOCATION="./build-artifacts/provisioning-gsa.json"
NODE_KEY_LOCATION="./build-artifacts/node-gsa.json"


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
  compute.googleapis.com \
  containerregistry.googleapis.com \
  secretmanager.googleapis.com \
  servicemanagement.googleapis.com \
  serviceusage.googleapis.com \
  sourcerepo.googleapis.com


### Set roles for GSA
declare -a ROLES=(
  "roles/viewer"
  "roles/monitoring.editor"
  "roles/gkehub.gatewayAdmin"
  "roles/gkehub.editor"
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
    --condition="None" \
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
