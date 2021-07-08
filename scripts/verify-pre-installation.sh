#!/bin/bash

PREFIX_DIR=$(dirname -- "$0")
source ${PREFIX_DIR}/cloud/gce-helper.vars

ERROR=0
if [[ ! -x $(command -v gcloud) ]]; then
    echo "Error: gcloud (Google Cloud SDK) command is required, but not installed."
    ERROR=1
fi

if [[ ! -x $(command -v envsubst) ]]; then
    echo "Error: envsubst (gettext) command is required, but not installed."
    ERROR=1
fi

if [[ ! -x $(command -v ssh-keygen) ]]; then
    echo "Error: ssh-keygen (SSH) command is required, but not installed."
    ERROR=1
fi

if [[ "${ERROR}" -eq 1 ]]; then
    echo "Required applications are not present on this host machine. Please install and re-try"
    exit 1
fi

# Asymetric key for SSH cloud instances required ahead of time
if [[ -z "${SSH_PUB_KEY_LOCATION}" ]]; then
    if [[ ! -f "${SSH_PUB_KEY_LOCATION}" ]]; then
        echo "The ENV variable 'SSH_PUB_KEY_LOCATION' does not point to a public key used for SSH access. Please refer to one-time setup (step 2) to generate the key pair."
        exit 1
    fi
else
    if [[ ! -f "${HOME}/.ssh/cnucs-cloud.pub" ]]; then
        echo "Cloud implementations requires a key pair for SSH access. Please refer to one-time setup (step 2) to generate the key pair."
        exit 1
    fi
fi

ERROR=0
# Default to gcloud if not set
if [[ -z "${PROJECT_ID}" ]]; then
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
fi

if [[ -z "${PROJECT_ID}" ]]; then
    echo "Error: No project ID set"
    ERROR=1
fi

# Default to gcloud if not set
if [[ -z "${ZONE}" ]]; then
    ZONE=$(gcloud config get-value compute/zone 2>/dev/null)
fi

if [[ -z "${ZONE}" ]]; then
    echo "Error: No zone set"
    ERROR=1
fi

if [[ -z "${LOCAL_GSA_FILE}" ]]; then
    echo "Error: A local GSA key file does not exist. Please run ./scripts/create-primary-gsa.sh"
    ERROR=1
fi

if [[ -z "${SCM_TOKEN_USER}" || -z "${SCM_TOKEN_TOKEN}" ]]; then
    echo "Error: Gitlab personal access token variable for USER and/or TOKEN not set. Please refer to 'Pre Installation Steps'"
    ERROR=1
fi

if [[ "${ERROR}" -eq 1 ]]; then
    echo "One or more error need to be fixed before this stage is complete."
    exit 1
else
    echo -e "\n\nSUCCESS!!\n\nProceed!!\n"
fi
