# GSA Key used for provisioning (result of running ./scripts/create-primary-gsa.sh)
export LOCAL_GSA_FILE=$(pwd)/build-artifacts/consumer-edge-gsa.json
###
### GCP Project Settings (change if needed per each provisioning run)
###
# GCP Project ID
export PROJECT_ID="$PROJECT_ID"
# Bucket to store cluster snapshot information
export SNAPSHOT_GCS="$PROJECT_ID-cluster-snapshots"
# GCP Project Region (Adjust as desired)
export REGION="$REGION"
# GCP Project Zone (Adjust as desired)
export ZONE="$ZONE"
###
### ACM Settings.  ACM Repos have several authentication to access the repository.
###
### Options are: none (default), token, gcpserviceaccount, ssh
###
export ROOT_REPO_TYPE="token"
######  SSH Type #############
# Path to the SSH private key for the SSH user type (must be in build-artifacts/ folder)
# export SCM_SSH_PRIVATE_KEYFILE="$(pwd)/build-artifacts/scm-ssh-private-key-example"
######  Token Type #############
# Values for Personal Access Token when REPO_TYPE is "token"
export SCM_TOKEN_USER="$SCM_TOKEN_USER" # Only used if REPO_TYPE is "token"
export SCM_TOKEN_TOKEN="$SCM_TOKEN_TOKEN" # Only used if REPO_TYPE is "token"
###
### Root Repo URL
###    NOTE: ROOT_REPO_TYPE of "ssh" MUST start with ssh:// (not git://)
###    NOTE: ROOT_REPO_TYPE of "gcpserviceaccount" needs to start with "https://source.developers.google.com"
###
export ROOT_REPO_URL="https://gitlab.com/gcp-solutions-public/retail-edge/root-repo-public-template.git"
export ROOT_REPO_BRANCH="main"
export ROOT_REPO_DIR="/config"
######  Cluster Name for ACM #############
# Set the name of the cluster for ACM to use (NOTE: If provisioning multiple clusters, this is not an effective naming method)
# export CLUSTER_ACM_NAME="location-1"    # Default if not set is defined on the primary_machine of the host-vars
###
### OIDC Settings
###
# OIDC Configuration (off by default)
export OIDC_CLIENT_ID="" # Optional, requires GCP API setup work
export OIDC_CLIENT_SECRET="" # Optional
export OIDC_USER="" # Optional
export OIDC_ENABLED="false" # Flip to true IF implementing OIDC on cluster