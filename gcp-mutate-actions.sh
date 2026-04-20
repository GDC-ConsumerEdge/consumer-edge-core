#!/bin/bash
# Copyright 2026 Google LLC
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

###############################################################################
# USER DEFINED VARIABLES
# Fill these in before running the script
###############################################################################

# Core Project Settings
export GOOGLE_PROJECT_ID="your-project-id"
export GOOGLE_SECRET_PROJECT_ID="${GOOGLE_PROJECT_ID}" # Usually the same
export CLUSTER_NAME="your-cluster-name"
export GOOGLE_REGION="us-central1"

# Storage / SDS Settings
export STORAGE_PROVIDER="robin" # options: robin, longhorn, none
export SCM_TOKEN_USER="your-git-user"
export SCM_TOKEN_TOKEN="your-git-token"

# Bucket Names (Defaults derived from project/cluster)
export SNAPSHOT_GCS_BUCKET_BASE="${GOOGLE_PROJECT_ID}-${CLUSTER_NAME}-snapshot"
export STORAGE_PROVIDER_GCS_BUCKET_NAME="${GOOGLE_PROJECT_ID}-${CLUSTER_NAME}-sds-backup"
export STORAGE_PROVIDER_AUTH_SECRET="${STORAGE_PROVIDER}-git-creds"
export STORAGE_PROVIDER_HMAC_GCM_SECRET="${GOOGLE_PROJECT_ID}-${CLUSTER_NAME}-sds-hmac-secret"

###############################################################################
# SCRIPT LOGIC
###############################################################################

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "ERROR: gcloud CLI is not installed."
    exit 1
fi

echo "--- 1. Enabling GCP Services ---"
GCP_SERVICES=(
    "anthos.googleapis.com" "anthosaudit.googleapis.com" "anthosgke.googleapis.com"
    "cloudresourcemanager.googleapis.com" "connectgateway.googleapis.com"
    "container.googleapis.com" "gkeconnect.googleapis.com" "gkehub.googleapis.com"
    "kubernetesmetadata.googleapis.com" "iam.googleapis.com" "iamcredentials.googleapis.com"
    "logging.googleapis.com" "monitoring.googleapis.com" "opsconfigmonitoring.googleapis.com"
    "secretmanager.googleapis.com" "serviceusage.googleapis.com" "stackdriver.googleapis.com"
    "storage.googleapis.com"
)
gcloud services enable "${GCP_SERVICES[@]}" --project="${GOOGLE_PROJECT_ID}"

echo "--- 2. Enabling ACM API ---"
gcloud beta container hub config-management enable --project="${GOOGLE_PROJECT_ID}"

echo "--- 3. Creating Snapshot Bucket ---"
if ! gcloud storage ls --project="${GOOGLE_PROJECT_ID}" "gs://${SNAPSHOT_GCS_BUCKET_BASE}" &>/dev/null; then
    gcloud storage buckets create --project="${GOOGLE_PROJECT_ID}" "gs://${SNAPSHOT_GCS_BUCKET_BASE}"
else
    echo "Bucket gs://${SNAPSHOT_GCS_BUCKET_BASE} already exists."
fi

echo "--- 4. Managing Service Accounts and Keys ---"
# List of GSAs and their roles
declare -A GSAS=(
    ["abm-gcr-${CLUSTER_NAME}"]="roles/storage.objectViewer"
    ["abm-gke-con-${CLUSTER_NAME}"]="roles/gkehub.connect"
    ["abm-gke-reg-${CLUSTER_NAME}"]="roles/gkehub.admin"
    ["abm-ops-${CLUSTER_NAME}"]="roles/logging.logWriter roles/monitoring.metricWriter roles/stackdriver.resourceMetadata.writer roles/monitoring.dashboardEditor roles/opsconfigmonitoring.resourceMetadata.writer roles/kubernetesmetadata.publisher roles/compute.osLogin"
    ["es-k8s-${CLUSTER_NAME}"]="roles/secretmanager.secretAccessor roles/secretmanager.viewer"
    ["sds-backup-${CLUSTER_NAME}"]="roles/storage.admin"
    ["cdi-import-${CLUSTER_NAME}"]="roles/storage.objectViewer"
)

for GSA in "${!GSAS[@]}"; do
    echo "Processing GSA: ${GSA}"
    
    # Create GSA if missing
    if ! gcloud iam service-accounts describe "${GSA}@${GOOGLE_PROJECT_ID}.iam.gserviceaccount.com" --project="${GOOGLE_PROJECT_ID}" &>/dev/null; then
        gcloud iam service-accounts create "${GSA}" --display-name "ABM Managed GSA ${GSA}" --project="${GOOGLE_PROJECT_ID}"
    fi

    # Bind Roles
    for ROLE in ${GSAS[$GSA]}; do
        echo "  Adding role: ${ROLE}"
        gcloud projects add-iam-policy-binding "${GOOGLE_PROJECT_ID}" \
            --member="serviceAccount:${GSA}@${GOOGLE_PROJECT_ID}.iam.gserviceaccount.com" \
            --role="${ROLE}" --condition="None" --quiet
    done

    # Create Secret and Key if no enabled secret versions exist
    if ! gcloud secrets describe "${GSA}" --project="${GOOGLE_SECRET_PROJECT_ID}" &>/dev/null; then
        gcloud secrets create "${GSA}" --replication-policy="automatic" --project="${GOOGLE_SECRET_PROJECT_ID}"
    fi

    if [[ -z $(gcloud secrets versions list "${GSA}" --filter="state=enabled" --project="${GOOGLE_SECRET_PROJECT_ID}" --format="value(name)") ]]; then
        echo "  Generating new key and adding to Secret Manager..."
        KEY_FILE="/tmp/${GSA}-key.json"
        gcloud iam service-accounts keys create "${KEY_FILE}" \
            --iam-account="${GSA}@${GOOGLE_PROJECT_ID}.iam.gserviceaccount.com" --project="${GOOGLE_PROJECT_ID}"
        gcloud secrets versions add "${GSA}" --data-file="${KEY_FILE}" --project="${GOOGLE_SECRET_PROJECT_ID}"
        rm -f "${KEY_FILE}"
    fi
done

echo "--- 5. Storage Provider Specific Mutates ---"
if [[ "${STORAGE_PROVIDER}" != "none" ]]; then
    # Git Creds in GSM
    echo "Processing SDS Git Credentials..."
    if ! gcloud secrets describe "${STORAGE_PROVIDER_AUTH_SECRET}" --project="${GOOGLE_PROJECT_ID}" &>/dev/null; then
        gcloud secrets create "${STORAGE_PROVIDER_AUTH_SECRET}" --replication-policy="automatic" --project="${GOOGLE_PROJECT_ID}"
    fi
    echo -n "{\"token\": \"${SCM_TOKEN_TOKEN}\", \"username\": \"${SCM_TOKEN_USER}\"}" | \
        gcloud secrets versions add "${STORAGE_PROVIDER_AUTH_SECRET}" --project="${GOOGLE_PROJECT_ID}" --data-file=-

    # Backup Bucket
    echo "Processing SDS Backup Bucket..."
    if ! gcloud storage ls --project "${GOOGLE_PROJECT_ID}" "gs://${STORAGE_PROVIDER_GCS_BUCKET_NAME}" &>/dev/null; then
        gcloud storage buckets create --project "${GOOGLE_PROJECT_ID}" "gs://${STORAGE_PROVIDER_GCS_BUCKET_NAME}"
        echo "do not remove this file" | gcloud storage cp - "gs://${STORAGE_PROVIDER_GCS_BUCKET_NAME}/.dontremove"
    fi

    if [[ "${STORAGE_PROVIDER}" == "longhorn" ]]; then
        # HMAC for Longhorn
        echo "Generating HMAC for Longhorn..."
        GSA_EMAIL="sds-backup-${CLUSTER_NAME}@${GOOGLE_PROJECT_ID}.iam.gserviceaccount.com"
        gcloud storage hmac create "${GSA_EMAIL}" --project "${GOOGLE_PROJECT_ID}" > /tmp/hmackey.txt
        
        # Prepare HMAC JSON for Secret Manager
        ACCESS_KEY=$(grep 'accessId' /tmp/hmackey.txt | awk '{print $2}')
        SECRET_KEY=$(grep 'secret' /tmp/hmackey.txt | awk '{print $2}')
        echo "{\"access_key\": \"${ACCESS_KEY}\", \"access_secret\": \"${SECRET_KEY}\", \"endpoint\": \"https://storage.googleapis.com\"}" > /tmp/hmacsecret.json
        
        if ! gcloud secrets describe "${STORAGE_PROVIDER_HMAC_GCM_SECRET}" --project="${GOOGLE_PROJECT_ID}" &>/dev/null; then
            gcloud secrets create "${STORAGE_PROVIDER_HMAC_GCM_SECRET}" --replication-policy="automatic" --project="${GOOGLE_PROJECT_ID}"
        fi
        gcloud secrets versions add "${STORAGE_PROVIDER_HMAC_GCM_SECRET}" --data-file="/tmp/hmacsecret.json" --project="${GOOGLE_PROJECT_ID}"
        rm -f /tmp/hmacsecret.json /tmp/hmackey.txt
    fi

    if [[ "${STORAGE_PROVIDER}" == "robin" ]]; then
        # Robin License Secret
        echo "Creating Robin License Secret placeholder..."
        if ! gcloud secrets describe "robin-sds-license" --project="${GOOGLE_SECRET_PROJECT_ID}" &>/dev/null; then
            gcloud secrets create "robin-sds-license" --replication-policy="automatic" --project="${GOOGLE_SECRET_PROJECT_ID}"
        fi
    fi
fi

echo "--- Finished ---"
echo "All GCP Mutate actions completed successfully."
