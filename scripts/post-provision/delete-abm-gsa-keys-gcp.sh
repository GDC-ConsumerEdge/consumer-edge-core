#!/bin/bash
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


###
### GSAs can only have a maximum of 10 GSA keys, and the installation process, with certain parameters, produce new GSA keys, this script removes all GSA keys for the primary agents in the system.
###
### This should ONLY be used when you know the explicit reason why you're doing this
###
CLUSTER_NAME=$1

read -p "This is a destructive operation meant for advanced users only. Proceed? (any character other than 'Y' will exit): " response

if [ "$response" != "Y" ]; then
    echo 'Canceling...'
    exit 0
fi

GSAs=(
    "abm-gke-register-agent-${CLUSTER_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
    "abm-cloud-operations-agent-${CLUSTER_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
    "abm-gcr-agent-${CLUSTER_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
    "abm-gke-connect-agent-${CLUSTER_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
    "external-secrets-k8s-${CLUSTER_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
     )

for GSA in "${GSAs[@]}"
do
    KEYS=( $(gcloud iam service-accounts keys list --iam-account=$GSA --format="value(name)" --managed-by="user" --project="${PROJECT_ID}") )
    echo "Removing ${#KEYS[@]} keys for: $GSA"
    for KEY in "${KEYS[@]}"
    do
        gcloud iam service-accounts keys delete $KEY --iam-account=$GSA --quiet --project="${PROJECT_ID}"
    done
    # # Remove the Secret Manager version (disable it)
    GSA_SECRET_KEY_NAME="${GSA%%@*}"

    SECRET_VERSIONS=( $(gcloud secrets versions list ${GSA_SECRET_KEY_NAME} --format="value(name)" --filter=state=enabled) )
    for SECRET_VERSION in "${SECRET_VERSIONS[@]}"
    do
        gcloud secrets versions disable "${SECRET_VERSION}" --secret="${GSA_SECRET_KEY_NAME}"
    done
done