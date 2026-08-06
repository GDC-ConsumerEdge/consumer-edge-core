output "snapshot_bucket_url" {
  description = "The URL of the snapshot bucket"
  value       = google_storage_bucket.snapshot_bucket.url
}

output "sds_backup_bucket_url" {
  description = "The URL of the SDS backup bucket"
  value       = var.storage_provider != "none" ? google_storage_bucket.sds_backup_bucket[0].url : null
}

output "service_account_emails" {
  description = "Emails of the created service accounts"
  value       = { for name, sa in google_service_account.sa : name => sa.email }
}

output "secret_ids" {
  description = "IDs of the created secrets in Secret Manager"
  value       = { for name, secret in google_secret_manager_secret.sa_secret : name => secret.id }
}

output "longhorn_hmac_access_id" {
  description = "The access ID for the Longhorn HMAC key"
  value       = var.storage_provider == "longhorn" ? google_storage_hmac_key.longhorn_hmac[0].access_id : null
}
