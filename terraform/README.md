# Reference Terraform Project for GCP Infrastructure

This directory contains a reference Terraform project to provision the GCP resources required for the Consumer Edge Core solution.

## Resources Created

- **GCP Services**: Enables all required Google Cloud APIs.
- **Service Accounts**: Creates the necessary Service Accounts for ABM operations.
- **IAM Bindings**: Assigns the required roles to the Service Accounts.
- **Secret Manager Secrets**: Stores the Service Account keys and storage provider credentials.
- **GCS Buckets**: Creates buckets for snapshots and storage provider backups.

## Prerequisites

- Terraform >= 1.0
- Google Cloud SDK (gcloud)
- A GCP Project with billing enabled

## Usage

1.  **Initialize Terraform**:
    ```bash
    terraform init
    ```

2.  **Configure Variables**:
    Create a `terraform.tfvars` file or pass variables via command line.
    ```hcl
    project_id   = "your-project-id"
    cluster_name = "your-cluster-name"
    # Optional
    region       = "us-central1"
    zone         = "us-central1-a"
    ```

3.  **Plan Changes**:
    ```bash
    terraform plan
    ```

4.  **Apply Changes**:
    ```bash
    terraform apply
    ```

## Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `project_id` | The GCP Project ID | `string` | - |
| `cluster_name` | The name of the cluster | `string` | - |
| `region` | The GCP Region | `string` | `"us-central1"` |
| `zone` | The GCP Zone | `string` | `"us-central1-a"` |
| `service_accounts` | List of Service Accounts to create and their roles | `list(object)` | (See defaults in `variables.tf`) |
| `snapshot_bucket_name` | Name of the GCS bucket for snapshots | `string` | `""` |
| `storage_provider_bucket_name` | Name of the GCS bucket for storage provider backups | `string` | `""` |
| `storage_provider` | Storage provider (robin, longhorn, none) | `string` | `"robin"` |
| `scm_token_user` | Git username for storage provider | `string` | `""` |
| `scm_token_token` | Git token for storage provider | `string` | `""` |

## Note on Service Account Keys

This Terraform project automatically generates JSON keys for the created Service Accounts and stores them in Google Secret Manager. While convenient for this reference project, consider using Workload Identity in production environments for better security.
