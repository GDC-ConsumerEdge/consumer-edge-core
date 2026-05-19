terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# 1. Enable GCP Services
resource "google_project_service" "services" {
  for_each = toset(var.gcp_services)
  project  = var.project_id
  service  = each.key

  disable_on_destroy = false
}

# 2. Enable ACM API (via Hub)
# Note: There isn't a direct "google_container_hub_config_management" resource in the standard provider that matches "gcloud beta container hub config-management enable"
# but we can enable the hub service.
resource "google_project_service" "anthos_config_management" {
  project = var.project_id
  service = "anthosconfigmanagement.googleapis.com"

  depends_on = [google_project_service.services]
}

# 3. Create Storage Buckets
resource "google_storage_bucket" "snapshot_bucket" {
  name     = var.snapshot_bucket_name != "" ? var.snapshot_bucket_name : "${var.project_id}-${var.cluster_name}-snapshot"
  project  = var.project_id
  location = var.region

  force_destroy = false
  storage_class = "STANDARD"

  uniform_bucket_level_access = true

  depends_on = [google_project_service.services]
}

resource "google_storage_bucket" "sds_backup_bucket" {
  count    = var.storage_provider != "none" ? 1 : 0
  name     = var.storage_provider_bucket_name != "" ? var.storage_provider_bucket_name : "${var.project_id}-${var.cluster_name}-sds-backup"
  project  = var.project_id
  location = var.region

  force_destroy = false
  storage_class = "STANDARD"

  uniform_bucket_level_access = true

  depends_on = [google_project_service.services]
}

# Placeholder file for SDS bucket
resource "google_storage_bucket_object" "sds_placeholder" {
  count   = var.storage_provider != "none" ? 1 : 0
  name    = ".dontremove"
  content = "do not remove this file"
  bucket  = google_storage_bucket.sds_backup_bucket[0].name
}

# 4. Manage Service Accounts, Roles, and Keys
resource "google_service_account" "sa" {
  for_each     = { for sa in var.service_accounts : sa.name => sa }
  account_id   = "${each.value.name}-${var.cluster_name}"
  display_name = "ABM Managed GSA ${each.value.name}-${var.cluster_name}"
  project      = var.project_id

  depends_on = [google_project_service.services]
}

resource "google_project_iam_member" "sa_roles" {
  for_each = {
    for pair in flatten([
      for sa in var.service_accounts : [
        for role in sa.roles : {
          sa_name = sa.name
          role    = role
        }
      ]
    ]) : "${pair.sa_name}-${pair.role}" => pair
  }

  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.sa[each.value.sa_name].email}"
}

# Secret Manager Secrets for Service Account Keys
resource "google_secret_manager_secret" "sa_secret" {
  for_each  = google_service_account.sa
  secret_id = each.value.account_id
  project   = var.project_id

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  depends_on = [google_project_service.services]
}

resource "google_service_account_key" "sa_key" {
  for_each           = google_service_account.sa
  service_account_id = google_service_account.sa[each.key].name
}

resource "google_secret_manager_secret_version" "sa_secret_version" {
  for_each    = google_secret_manager_secret.sa_secret
  secret      = each.value.id
  secret_data = base64decode(google_service_account_key.sa_key[each.key].private_key)
}

# 5. Storage Provider Specific Resources
# Git Credentials for Storage Provider
resource "google_secret_manager_secret" "sds_git_creds" {
  count     = var.storage_provider != "none" ? 1 : 0
  secret_id = "${var.storage_provider}-git-creds"
  project   = var.project_id

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  depends_on = [google_project_service.services]
}

resource "google_secret_manager_secret_version" "sds_git_creds_version" {
  count       = var.storage_provider != "none" && var.scm_token_token != "" ? 1 : 0
  secret      = google_secret_manager_secret.sds_git_creds[0].id
  secret_data = jsonencode({
    token    = var.scm_token_token
    username = var.scm_token_user
  })
}

# HMAC for Longhorn
resource "google_storage_hmac_key" "longhorn_hmac" {
  count                 = var.storage_provider == "longhorn" ? 1 : 0
  service_account_email = google_service_account.sa["sds-backup"].email
  project               = var.project_id
}

resource "google_secret_manager_secret" "longhorn_hmac_secret" {
  count     = var.storage_provider == "longhorn" ? 1 : 0
  secret_id = "${var.project_id}-${var.cluster_name}-sds-hmac-secret"
  project   = var.project_id

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  depends_on = [google_project_service.services]
}

resource "google_secret_manager_secret_version" "longhorn_hmac_version" {
  count  = var.storage_provider == "longhorn" ? 1 : 0
  secret = google_secret_manager_secret.longhorn_hmac_secret[0].id
  secret_data = jsonencode({
    access_key    = google_storage_hmac_key.longhorn_hmac[0].access_id
    access_secret = google_storage_hmac_key.longhorn_hmac[0].secret
    endpoint      = "https://storage.googleapis.com"
  })
}

# Robin License Secret Placeholder
resource "google_secret_manager_secret" "robin_license" {
  count     = var.storage_provider == "robin" ? 1 : 0
  secret_id = "robin-sds-license"
  project   = var.project_id

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  depends_on = [google_project_service.services]
}
