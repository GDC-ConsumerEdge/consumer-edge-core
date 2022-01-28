#!/bin/bash

PREFIX_DIR=$(dirname -- "$0")
source ${PREFIX_DIR}/cloud/gce-helper.vars
CWD=$(pwd)

ERROR=0
if [[ ! -x $(command -v gcloud) ]]; then
    echo "Error: gcloud (Google Cloud SDK) command is required, but not installed."
    ERROR=1
fi

ERROR=0
if [[ ! -x $(command -v python) ]]; then
    echo "Error: `python` command is required, but not installed or on the PATH."
    ERROR=1
fi

ERROR=0
if [[ ! -x $(command -v pip) ]]; then
    echo "Error: `pip` command is required, but not installed or on the PATH."
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

# Check for Python 3.8+
MIN_PYTHON=3
MIN_PYTHON_MINOR=8

PYTHON_VERSION=$(python -V | awk '{split($0,a," "); print a[2]}' ) # get just the number
PYTHON_SEMVER=( ${PYTHON_VERSION//./ } ) # split up semver

PYTHON_MAJOR=${PYTHON_SEMVER[0]}
PYTHON_MINOR=${PYTHON_SEMVER[1]}

if [[ ${PYTHON_MAJOR} -lt ${MIN_PYTHON} ]] || [[ ${PYTHON_MAJOR} -lt ${MIN_PYTHON} && ${PYTHON_MINOR} -lt ${MIN_PYTHON_MINOR} ]]; then
    echo "Error: python 3.8+ is required. Version ${PYTHON_MAJOR}.${PYTHON_MINOR}.x found"
    exit 1
fi

# Check for required PIP installations
PIP_PACKAGES=$(pip list 2> /dev/null)
REQUIRED=( "ansible" "dnspython" "requests" "google-auth" )
for i in "${REQUIRED[@]}"
do
	GREP=$(echo ${PIP_PACKAGES} | grep $i)
    if [[ -z "${GREP}" ]]; then
        echo "Error: PIP package ${i} is required. Please install with 'pip install ${i}' or 'pip install -r requirements.txt'"
        exit 1
    fi
done

# Check for Inventory files (GCP and/or Physical)
FILE="${CWD}/inventory"
GCP_INVENTORY=$(ls -al "${FILE}/gcp.yaml" 2> /dev/null)
PHYSICAL_INVENTORY=$(ls -al "${FILE}/inventory.yaml" 2> /dev/null)

if [[ -z "${GCP_INVENTORY}" ]]; then
    echo "Warning: GCP Inventory file is not found. This is not required, but if you are using GCE instances for installation, this inventory needs to be created. See ONE_TIME setup for details."
    echo "possible command might be: envsubst < templates/inventory-cloud-example.yaml > inventory/gcp.yaml"
fi

if [[ -z "${PHYSICAL_INVENTORY}" ]]; then
    echo "Warning: Physical Inventory file is not found. This is not required, but if you are using physical instances for installation, this inventory needs to be created. See ONE_TIME setup for details."
    echo "possible command might be: envsubst < templates/inventory-physical-example.yaml > inventory/inventory.yaml"
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
    echo "Error: An environment variable pointing to the local GSA key file does not exist. Please run ./scripts/create-primary-gsa.sh"
    ERROR=1
elif [[ ! -f $LOCAL_GSA_FILE ]]; then
    echo "Error: Local GSA file does not exist or is not placed where the ENV is pointing to."
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
    echo -e "\n\nSUCCESS, your environment is ready to run and install Anthos Consumer Edge!!\n"
fi
