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

# GSA Key used for provisioning (result of running ./scripts/create-primary-gsa.sh)
export PROVISIONING_GSA_FILE=$(pwd)/build-artifacts/provisioning-gsa.json
export NODE_GSA_FILE=$(pwd)/build-artifacts/node-gsa.json
###
### GCP Project Settings (change if needed per each provisioning run)
###
# GCP Project ID
export PROJECT_ID="${PROJECT_ID}"
# GCP Secret Manager Project ID
export SECRET_PROJECT_ID="${SECRET_PROJECT_ID:-$PROJECT_ID}"
# GCP Service Acocunt Project ID
export SA_PROJECT_ID="${SA_PROJECT_ID:-$PROJECT_ID}"

# GCP SSH firewall management for GCP CNUC access. Set to true to have gcloud set current public IP to SSH firewall access
export MANAGE_FIREWALL_RULES=false

# GCP Project Region (Adjust as desired)
export REGION="us-central1"
# GCP Project Zone (Adjust as desired)
export ZONE="us-central1-a"

# Determines which project contains the provisioning image. If PROVISIONING_IMAGE_PROJECT_ID is
# unset, it will default to the PROJECT_ID.
export PROVISIONING_IMAGE_PROJECT_ID=${PROVISIONING_IMAGE_PROJECT_ID:-$PROJECT_ID}

###
### ACM Settings.  ACM Repos have several authentication to access the repository.
###
######  Cluster Name for ACM #############
# Set the name of the cluster for ACM to use (NOTE: If provisioning multiple clusters, this is not an effective naming method)
export CLUSTER_ACM_NAME="gdc-demo"    # con-edge-cluster is the default for demos, for POC and other builds, set name in primary_machine of each cluster

# Bucket to store cluster snapshot information
export SNAPSHOT_GCS="${PROJECT_ID}-${CLUSTER_ACM_NAME}-snapshot"

### ACM Root Repo structure type. Default is hierarchy, but primary-root-repo-template is unstructured
export ROOT_REPO_STRUCTURE="unstructured"

### Authentication type of Root Repo (options are "none", "token", and "ssh")
export ROOT_REPO_TYPE="token"
######  SSH Type #############
# Path to the SSH private key for the SSH user type (must be in build-artifacts/ folder)
# export SCM_SSH_PRIVATE_KEYFILE="$(pwd)/build-artifacts/scm-ssh-private-key-example"

######  Token Type #############
# Values for Personal Access Token when REPO_TYPE is "token". Either set the varaible before `envsubt` or replace "change-me" with the approprate values
export SCM_TOKEN_USER="${SCM_TOKEN_USER:-CHANGE_ME}"    # Only used if REPO_TYPE is "token"
export SCM_TOKEN_TOKEN="${SCM_TOKEN_TOKEN:-CHANGE_ME}"  # Only used if REPO_TYPE is "token"

###
### Primary Root Repo URL
###    NOTE: ROOT_REPO_TYPE of "ssh" MUST start with ssh:// (not git://)
###
export ROOT_REPO_URL="https://gitlab.com/gcp-solutions-public/retail-edge/primary-root-repo-template.git"
export ROOT_REPO_BRANCH="main"
export ROOT_REPO_DIR="/config/clusters/${CLUSTER_ACM_NAME}/meta"

export CONNECT_GATEWAY_ENABLED="false" # This only creates a service acocunt that can be used for kubectl commands
export SDS_BACKUP_ENABLED="true" # This crates the service acocunt used by SDS to take backups on to GCS bucket

###
### OIDC Settings
###
# OIDC Configuration (off by default)
export OIDC_CLIENT_ID="" # Optional, requires GCP API setup work
export OIDC_CLIENT_SECRET="" # Optional
export OIDC_USER="" # Optional
export OIDC_ENABLED="false" # Flip to true IF implementing OIDC on cluster

###### HTTP / HTTPS Proxy #########
# Variables for HTTP proxy (leave empty or remove if not used)
export HTTP_PROXY_USER=""
export HTTP_PROXY_PASS=""
export HTTP_PROXY_ADDR=""
export HTTP_PROXY_PORT=""
export HTTP_PROXY_PROTOCOL="" # http or https
# Variables for HTTPS proxy (leave empty or remove if not used)
export HTTPS_PROXY_USER=""
export HTTPS_PROXY_PASS=""
export HTTPS_PROXY_ADDR=""
export HTTPS_PROXY_PORT=""
export HTTPS_PROXY_PROTOCOL="" # http or https

### SDS Configuration
# Optional configuration for the Cluter Trait Repo of the target SDS. All of the below commented out configuration
#   are the default configurations programmed in the provisioning process (ie, they do not need to be explicitly set if
#   they are not different than the below values)
####
# export SDS_REPO_URL="https://gitlab.com/gcp-solutions-public/retail-edge/available-cluster-traits/robin-io-anthos.git"
# export SDS_REPO_BRANCH="main"
# export SDS_REPO_STRUCTURE="hierarchy" # vs "unstructred"
# export SDS_TOKEN_USER="${SCM_TOKEN_USER}"
# export SDS_TOKEN_TOKEN="${SCM_TOKEN_TOKEN}"

# Uncomment to use RHEL8 or fill in with supported OS/family/project as needed (advanced)
# export MACHINE_OS_FAMILY="rhel-8"
# export MACHINE_OS_PROJECT="rhel-cloud"