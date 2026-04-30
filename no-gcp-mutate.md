# GCloud Mutate Task Summary

This document summarizes all Ansible tasks within the project tagged with `gcloud-mutate`. These tasks perform state-changing operations in a Google Cloud Project and can be run independently via the provided bash scripts.

## Role: `gcp-setup`

### 1. Enable Google Cloud Services
*   **Task:** `Enable services`
*   **Description:** Enables all required Google Cloud APIs for the project (Anthos, IAM, Logging, etc.).
*   **Bash Script:**
    ```bash
    gcloud services enable \
      anthos.googleapis.com \
      anthosaudit.googleapis.com \
      anthosgke.googleapis.com \
      cloudresourcemanager.googleapis.com \
      connectgateway.googleapis.com \
      container.googleapis.com \
      gkeconnect.googleapis.com \
      gkehub.googleapis.com \
      kubernetesmetadata.googleapis.com \
      iam.googleapis.com \
      iamcredentials.googleapis.com \
      logging.googleapis.com \
      monitoring.googleapis.com \
      opsconfigmonitoring.googleapis.com \
      secretmanager.googleapis.com \
      serviceusage.googleapis.com \
      stackdriver.googleapis.com \
      storage.googleapis.com \
      --project="${GOOGLE_PROJECT_ID}"
    ```

### 2. Enable ACM API
*   **Task:** `Enable ACM API in GCP`
*   **Description:** Enables Anthos Config Management on the fleet hub.
*   **Bash Script:**
    ```bash
    gcloud beta container hub config-management enable --project="${GOOGLE_PROJECT_ID}"
    ```

### 3. Create Snapshot GCS Bucket
*   **Task:** `Create the bmctl snapshot backup GCS bucket`
*   **Description:** Ensures a storage bucket exists for cluster snapshots.
*   **Bash Script:**
    ```bash
    gcloud storage buckets create --project="${GOOGLE_PROJECT_ID}" "gs://${SNAPSHOT_GCS_BUCKET_BASE}"
    ```

### 4. Manage Service Accounts (GSAs)
*   **Tasks:** `Create or Enable Service Accounts` and `Add role bindings to service accounts`
*   **Description:** Creates/enables GSAs (e.g., `abm-gcr`, `abm-ops`) and assigns required IAM roles.
*   **Bash Script:**
    ```bash
    # Example for one GSA
    gcloud iam service-accounts create "${GSA_NAME}" --display-name "${DESCRIPTION}" --project="${GOOGLE_PROJECT_ID}"
    gcloud projects add-iam-policy-binding "${GOOGLE_PROJECT_ID}" \
      --member="serviceAccount:${GSA_NAME}@${GOOGLE_PROJECT_ID}.iam.gserviceaccount.com" \
      --role="${ROLE}" --condition="None"
    ```

### 5. Create GSA Keys and GSM Secrets
*   **Task:** `Create GSM Secret and GSA Keys`
*   **Description:** Generates service account keys and stores them as versioned secrets in Secret Manager.
*   **Bash Script:**
    ```bash
    gcloud secrets create "${SECRET_NAME}" --replication-policy="automatic" --project="${GOOGLE_SECRET_PROJECT_ID}"
    gcloud iam service-accounts keys create "/tmp/${KEYFILE}" \
      --iam-account="${GSA_NAME}@${GOOGLE_PROJECT_ID}.iam.gserviceaccount.com" --project="${GOOGLE_PROJECT_ID}"
    gcloud secrets versions add "${SECRET_NAME}" --data-file="/tmp/${KEYFILE}" --project="${GOOGLE_SECRET_PROJECT_ID}"
    ```

### 6. SDS Git Credentials
*   **Task:** `Add new version to SDS git-creds to Google Secrets Manager`
*   **Description:** Stores Git provider credentials in Secret Manager for SDS components.
*   **Bash Script:**
    ```bash
    echo -n "{\"token\": \"${SCM_TOKEN_TOKEN}\", \"username\": \"${SCM_TOKEN_USER}\"}" | \
    gcloud secrets versions add "${STORAGE_PROVIDER_AUTH_SECRET}" --project="${GOOGLE_PROJECT_ID}" --data-file=-
    ```

### 7. SDS Backup Infrastructure
*   **Tasks:** `Create SDS Backup Bucket` and `Create new HMAC key for longhorn`
*   **Description:** Sets up GCS buckets and HMAC authentication for storage provider backups.
*   **Bash Script:**
    ```bash
    gcloud storage buckets create --project "${GOOGLE_PROJECT_ID}" "gs://${STORAGE_PROVIDER_GCS_BUCKET_NAME}"
    gcloud storage hmac create "sds-backup-agent-${CLUSTER_NAME}@${GOOGLE_PROJECT_ID}.iam.gserviceaccount.com" --project "${GOOGLE_PROJECT_ID}"
    ```

## Role: `abm-software`

### 8. Robin License Secret
*   **Task:** `Create Robin GCP Secret (robin-sds-license)`
*   **Description:** Creates a placeholder secret in GSM for the Robin SDS license.
*   **Bash Script:**
    ```bash
    gcloud secrets create "robin-sds-license" --replication-policy="automatic" --project="${GOOGLE_SECRET_PROJECT_ID}"
    ```
