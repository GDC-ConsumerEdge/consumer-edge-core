
# GSA Key used for provisioning (result of running ./scripts/create-primary-gsa.sh)
export LOCAL_GSA_FILE=$(pwd)/build-artifacts/consumer-edge-gsa.json
# GCP Project ID
export PROJECT_ID="### GCP PROJECT ID ###"

# GCP Project Region
export REGION="us-west1"
# GCP Project Zone
export ZONE="us-west1-b"

# Gitlab Personal Access Token credentials (generated in Quick Start step 2)
export SCM_TOKEN_USER="### Repo Login Name ###"
export SCM_TOKEN_TOKEN="### Repo PAT Token ###"

# Default  Root Repo
export ROOT_REPO_URL="https://gitlab.com/gcp-solutions-public/retail-edge/root-repo-ml-edge.git"

# OIDC Configuration (off by default)
export OIDC_CLIENT_ID="" # Optional, requires GCP API setup work
export OIDC_CLIENT_SECRET="" # Optional
export OIDC_USER="" # Optional
export OIDC_ENABLED="false" # Flip to true IF implementing OIDC on cluster