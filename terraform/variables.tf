variable "project_id" {
  description = "The GCP Project ID"
  type        = string
}

variable "region" {
  description = "The GCP Region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The GCP Zone"
  type        = string
  default     = "us-central1-a"
}

variable "cluster_name" {
  description = "The name of the cluster"
  type        = string
}

variable "service_accounts" {
  description = "List of Service Accounts to create and their roles"
  type = list(object({
    name        = string
    description = string
    roles       = list(string)
  }))
  default = [
    {
      name        = "abm-gcr"
      description = "ABM GCR Agent Account"
      roles       = ["roles/storage.objectViewer"]
    },
    {
      name        = "abm-gke-con"
      description = "ABM GKE Connect Agent Service Account"
      roles       = ["roles/gkehub.connect"]
    },
    {
      name        = "abm-gke-reg"
      description = "ABM GKE Connect Register Account"
      roles       = ["roles/gkehub.admin"]
    },
    {
      name        = "abm-ops"
      description = "ABM Cloud Operations Service Account"
      roles = [
        "roles/logging.logWriter",
        "roles/monitoring.metricWriter",
        "roles/stackdriver.resourceMetadata.writer",
        "roles/monitoring.dashboardEditor",
        "roles/opsconfigmonitoring.resourceMetadata.writer",
        "roles/kubernetesmetadata.publisher",
        "roles/compute.osLogin"
      ]
    },
    {
      name        = "es-k8s"
      description = "External Secrets Service Account"
      roles = [
        "roles/secretmanager.secretAccessor",
        "roles/secretmanager.viewer"
      ]
    },
    {
      name        = "sds-backup"
      description = "SDS agent taking volume backups on cloud storage"
      roles       = ["roles/storage.admin"]
    },
    {
      name        = "cdi-import"
      description = "Agent used for CDI image access"
      roles       = ["roles/storage.objectViewer"]
    }
  ]
}

variable "snapshot_bucket_name" {
  description = "Name of the GCS bucket for snapshots"
  type        = string
  default     = ""
}

variable "storage_provider_bucket_name" {
  description = "Name of the GCS bucket for storage provider backups"
  type        = string
  default     = ""
}

variable "storage_provider" {
  description = "Storage provider (robin, longhorn, none)"
  type        = string
  default     = "robin"
}

variable "scm_token_user" {
  description = "Git username for storage provider"
  type        = string
  default     = ""
}

variable "scm_token_token" {
  description = "Git token for storage provider"
  type        = string
  default     = ""
  sensitive   = true
}

variable "gcp_services" {
  description = "List of GCP services to enable"
  type        = list(string)
  default = [
    "anthos.googleapis.com",
    "anthosaudit.googleapis.com",
    "anthosgke.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "connectgateway.googleapis.com",
    "container.googleapis.com",
    "gkeconnect.googleapis.com",
    "gkehub.googleapis.com",
    "kubernetesmetadata.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "opsconfigmonitoring.googleapis.com",
    "secretmanager.googleapis.com",
    "serviceusage.googleapis.com",
    "stackdriver.googleapis.com",
    "storage.googleapis.com"
  ]
}
