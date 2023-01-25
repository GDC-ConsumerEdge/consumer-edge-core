#!/bin/bash

# Requirements
# - Need to have gcloud setup and configured to target $PROJECT_ID
# - Need to have run ./scripts/create-gsa.sh and have the JSON key placed in ./build-artifacts

# Need to generate or validate
# - Create GCE instances (or verify communication with them)
# - Inventory files (cloud/physical)
# - Environment variables (via .envrc)


# verify all ready for install
# - All hosts are reachable with passwordless SSH
# - All environment varaibles have been defined
# docker run -v "$(pwd):/var/consumer-edge-install:ro" -it gcr.io/${GCP_PROJECT}/consumer-edge-install:latest /bin/bash -c /var/consumer-edge-install/scripts/health-check.sh

### Run docker
# docker pull gcr.io/${GCP_PROJECT}/consumer-edge-install:latest
### NOTE: Use this in the "verify" section above
# docker run -v "$(pwd):/var/consumer-edge-install:ro" -it gcr.io/${GCP_PROJECT}/consumer-edge-install:latest /bin/bash -c /var/consumer-edge-install/scripts/health-check.sh


# Run installation (command could be run manually too or instead)
# docker run -v "$(pwd):/var/consumer-edge-install:ro" -it gcr.io/${GCP_PROJECT}/consumer-edge-install:latest /bin/bash -c ansible-playbook -i inventory all-full-install.yaml

ERROR_COLOR="\e[1;31m"
INFO_COLOR="\e[1;37m"
WARN_COLOR="\e[1;33m"
DEBUG_COLOR="\e[1;35m"
DEFAULT_COLOR="\e[1;32m"
ENDCOLOR="\e[0m"

PROJECT_NAME_MAX_LENGTH=17

function pretty_print() {
    MSG=$1
    LEVEL=${2:-DEFAULT}

    if [[ -z "${MSG}" ]]; then
        return
    fi

    case "$LEVEL" in
        "DEFAULT")
            echo -e $(printf "${DEFAULT_COLOR}${MSG}${ENDCOLOR}")
            ;;
        "ERROR")
            echo -e $(printf "${ERROR_COLOR}${MSG}${ENDCOLOR}")
            ;;
        "WARN")
            echo -e $(printf "${WARN_COLOR}${MSG}${ENDCOLOR}")
            ;;
        "INFO")
            echo -e $(printf "${INFO_COLOR}${MSG}${ENDCOLOR}")
            ;;
        "DEBUG")
            echo -e $(printf "${DEBUG_COLOR}${MSG}${ENDCOLOR}")
            ;;
        *)
            echo "NO MATCH"
            ;;
    esac
}



echo -e "===============================================\nThis is a script to manage the installation of the Consumer Edge for Cloud (GCE) demo instances.\n==============================================="

## Check State of system

ERROR=0
if [[ ! -x $(command -v gcloud) ]]; then
    prett_print "ERROR: gcloud (Google Cloud SDK) command is required, but not installed." "ERROR"
    ERROR=1
else
    pretty_print "PASS: gcloud command found"
fi

if [[ ! -x $(command -v envsubst) ]]; then
    pretty_print "WARN: envsubst (gettext) command is optional and may be used, but not installed." "WARN"
else
    pretty_print "PASS: envsubst command found"
fi

if [[ ! -x $(command -v ssh-keygen) ]]; then
    pretty_print "ERROR: ssh-keygen (SSH) command is required, but not installed. Please install OpenSSH" "ERROR"
    ERROR=1
else
    pretty_print "PASS: ssh-keygen command found"
fi


if [[ "${ERROR}" -eq 1 ]]; then
    echo "Required applications are not present on this host machine. Please install and re-try"
    exit 1
fi

# reset for configuration errors
ERROR=0

# Check for Private Encrypted SSH Keys
PROJ_LENGTH=`echo ${PROJECT_ID} | wc -c`
if [[ ${PROJ_LENGTH} > ${PROJECT_NAME_MAX_LENGTH} ]]; then
    pretty_print "WARN: GCP Project names might be a concern, it is longer than recommended '${PROJECT_NAME_MAX_LENGTH}' characters" "WARN"
else
    pretty_print "PASS: Project name length is ok"
fi

# Check for Private Encrypted SSH Keys
if [[ ! -f "./build-artifacts/consumer-edge-machine.encrypted" ]]; then
    pretty_print "ERROR: Encrypted SSH Key './build-artifacts/consumer-edge-machine.encrypted' was not found, did you generate and encrypt the private key?" "ERROR"
    exit 1
else
    pretty_print "PASS: Encrypted SSH Private Key found"
fi

# Check for Public SSH Key
if [[ ! -f "./build-artifacts/consumer-edge-machine.pub" ]]; then
    pretty_print "ERROR: Public SSH Key './build-artifacts/consumer-edge-machine.pub' was not found, did you generate the public key along with the private key?" "ERROR"
    exit 1
else
    pretty_print "PASS: Public SSH Key found"
fi

# Check for GSA Keys
if [[ ! -f "./build-artifacts/provisioning-gsa.json" ]]; then
    pretty_print "ERROR: GSA JSON key './build-artifacts/provisioning-gsa.json' does not exist, please generate a key using ./script/create-gsa.sh and try again." "ERROR"
    exit 1
else
    pretty_print "PASS: GSA Key found"
fi

# Check for GCP Inventory
if [[ ! -f "./inventory/gcp.yml" ]]; then
    pretty_print "WARNING: GCP Inventory file was not found. IF using GCE instances, this file MUST be setup and working." "WARN"
else
    pretty_print "PASS: GCP Inventory file found"
fi

# Check for GCP Inventory
if [[ ! -f "./inventory/inventory.yaml" && ! -f "./inventory/inventory.yml" ]]; then
    pretty_print "WARNING: Physical Inventory file was not found. IF using physical devices, this file MUST be setup and working." "WARN"
else
    pretty_print "PASS: Physical inventory file found"
fi

# Check for GSA Keys
if [[ ! -f "./.envrc" ]]; then
    pretty_print "ERROR: Environment variables file .envrc was not found or is not accessible." "ERROR"
    exit 1
else
    pretty_print "PASS: Environment variables (.envrc) file found"
fi

# Check for GCR docker credentials helper
HAS_GCR=$(cat ${HOME}/.docker/config.json | grep "gcloud")

if [[ -z "${HAS_GCR}" ]]; then
    pretty_print "Authorizing docker for gcr.io"
    gcloud auth configure-docker --quiet --verbosity=critical --no-user-output-enabled
fi

# Check for SSH Keys
if [[ -z "${PROJECT_ID}" ]]; then
    pretty_print "ERROR: Environment variable 'PROJECT_ID' does not exist, please set and try again." "ERROR"
    exit 1
else
    pretty_print "PASS: PROJECT_ID (${PROJECT_ID}) variable is set."
fi

# Check for SSH Keys
if [[ ! -z "${HTTP_PROXY_ADDR}" ]]; then
    pretty_print "INFO: HTTP Proxy (${HTTP_PROXY_ADDR}) is being installed" "INFO"
else
    pretty_print "INFO: No HTTP proxy indicated" "INFO"
fi

if [[ -z "${PROVISIONING_GSA_FILE}" ]]; then
    pretty_print "ERROR: An environment variable pointing to the provisioning GSA key file does not exist. Please run ./scripts/create-gsa.sh and place the key as ./build-artifacts/provisioning-gsa.json" "ERROR"
    ERROR=1
elif [[ ! -f $PROVISIONING_GSA_FILE ]]; then
    pretty_print "ERROR: Provisioning GSA file does not exist or is not placed where the ENV is pointing to." "ERROR"
    ERROR=1
else
    pretty_print "PASS: Provisioning GSA key (${PROVISIONING_GSA_FILE})"
fi

if [[ -z "${NODE_GSA_FILE}" ]]; then
    pretty_print "ERROR: An environment variable pointing to the node GSA key file does not exist. Please run ./scripts/create-gsa.sh and place the key as ./build-artifacts/node-gsa.json" "ERROR"
    ERROR=1
elif [[ ! -f $NODE_GSA_FILE ]]; then
    pretty_print "ERROR: Node GSA file does not exist or is not placed where the ENV is pointing to." "ERROR"
    ERROR=1
else
    pretty_print "PASS: Node GSA key (${NODE_GSA_FILE})"
fi

### Validate ROOT_REPO_TYPE & ROOT_REPO URL
# Options are none (default), token, gcpserviceaccount, ssh
# IF default, only ROOT_REPO_URL needs to be filled (http or https prefix)
# IF SSH, SCM_SSH_PRIVATE_KEYFILE must point to a file and ROOT_REPO_URL needs to start with "ssh://"
# IF TOKEN, SCM_TOKEN_USER and SCM_TOKEN_TOKEN must be filled and ROOT_REPO_URL starts with http or https
# IF gcpserviceaccount, ROOT_REPO_URL must start and contain https://source.developers.google.com
###

case "${ROOT_REPO_TYPE}" in

  "ssh")
    if [[ -z "${SCM_SSH_PRIVATE_KEYFILE}" ]]; then
        pretty_print "ERROR: SCM_SSH_PRIVATE_KEYFILE is required for ROOT_REPO_TYPE = 'ssh'" "ERROR"
        ERROR=1
    elif [[ ! -f "${SCM_SSH_PRIVATE_KEYFILE}" ]]; then
        pretty_print "ERROR: SCM_SSH_PRIVATE_KEYFILE must point to the PRIVATE key registered with SCM" "ERROR"
        ERROR=1
    fi
    ;;

  "none")
    ;;

  "gcpserviceaccount")
    ;;

  "token")
    if [[ -z "${SCM_TOKEN_USER}" ]]; then
        pretty_print "ERROR: SCM_TOKEN_USER is required for ROOT_REPO_TYPE = 'token'" "ERROR"
        ERROR=1
    fi
    if [[ -z "${SCM_TOKEN_TOKEN}" ]]; then
        pretty_print "ERROR: SCM_TOKEN_TOKEN is required for ROOT_REPO_TYPE = 'token'" "ERROR"
        ERROR=1
    fi
    ;;

  *)
    pretty_print "ERROR: ROOT_REPO_TYPE environment variable is not set to 'token', 'none', 'gcpserviceaccount' or 'ssh'" "ERROR"
    ERROR=1
    ;;
esac

case "${ROOT_REPO_TYPE}" in

  "none" | "token")
    if [[ ! "${ROOT_REPO_URL}" =~ ^http\:\/\/*|^https\:\/\/* ]]; then
        pretty_print "ERROR: ROOT_REPO_URL requires http:// or https:// protocol when using ROOT_REPO_TYPE = '${ROOT_REPO_TYPE}'" "ERROR"
        ERROR=1
    fi
    ;;

  "ssh")
    if [[ ! "${ROOT_REPO_URL}" =~ ^ssh\:\/\/* ]]; then
        pretty_print "ERROR: ROOT_REPO_URL requires ssh:// protocol when using ROOT_REPO_TYPE = '${ROOT_REPO_TYPE}'" "ERROR"
        ERROR=1
    fi
    ;;

  "gcpserviceaccount")
    if [[ ! "${ROOT_REPO_URL}" =~ ^https\:\/\/source\.developers\.google\.com* ]]; then
        pretty_print "ERROR: ROOT_REPO_URL requires https://source.developers.google.com protocol when using ROOT_REPO_TYPE = '${ROOT_REPO_TYPE}" "ERROR"
        ERROR=1
    fi
    ;;

esac

if [[ $ERROR -lt 1 ]]; then
    pretty_print "INFO: Root Repo Authentication Type is '${ROOT_REPO_TYPE}'" "INFO"
    pretty_print "PASS: Root Repo is set to: (${ROOT_REPO_URL})"
    case "${ROOT_REPO_TYPE}" in

    "ssh")
        pretty_print "PASS: Using '${SCM_SSH_PRIVATE_KEYFILE}' as the SSH private key for SCM"
        ;;
    "none")
        pretty_print "INFO: ROOT_REPO_TYPE is 'none' indicating ROOT_REPO_URL does not require authentication."
        ;;
    "token")
        pretty_print "PASS: Using SCM Token User: ${SCM_TOKEN_USER}"
        pretty_print "PASS: Using SCM Token Value: $(echo ${SCM_TOKEN_TOKEN} | sed 's/^....../******/')"
        ;;
    esac

fi


if [[ "${ERROR}" -eq 1 ]]; then
    echo ""
    pretty_print "Required configurations are not present in their intended location. Please re-configure and re-try again." "ERROR"
    echo ""
    exit 1
fi

ACCEPT_OSS_MESSAGE=`cat <<EOF
This solution uses Open Source tools that are not explicity covered by Google Support.

OSS solutions used but not supported:
* External Secrets
* Ansible Community (Ansible Playbook and Ansible Pull)

Optional Tooling (config setting in all.yaml under flag "optional_tools")
* kubens & kubectx
* kubestr
* K9s

Do you accept the responsiblity of supporting these OSS tools as listed do you want to proceed? (y/N):
EOF`

echo ""
read -p "$ACCEPT_OSS_MESSAGE" proceed

if [[ -z "${proceed}" || "${proceed}" =~ ^([nN][oO]|[nN])$ ]]; then
    echo "Aborting."
    exit 0
fi

echo ""
read -p "Check the values above and if correct, do you want to proceed? (y/N): " proceed

if [[ "${proceed}" =~ ^([yY][eE][sS]|[yY])$ ]]; then

    pretty_print "Starting the installation"

    pretty_print "Pulling docker install image...(please be patient, can be 1-2 minutes on first image pull)"

    IMAGE_PATH="gcr.io/${PROVISIONING_IMAGE_PROJECT_ID}/consumer-edge-install:latest"
    RESULT=$(docker pull ${IMAGE_PATH})

    if [[ $? -gt 0 ]]; then
        pretty_print "ERROR: Cannot pull Consumer Edge Install image" "ERROR"
        exit 1
    fi

    pretty_print " "
    pretty_print "=============================="
    pretty_print "Starting the docker container. You will need to run the following 2 commands (cut-copy-paste)"
    pretty_print "=============================="
    pretty_print "1: ./scripts/health-check.sh"
    pretty_print "2: ansible-playbook all-full-install.yml -i inventory"
    pretty_print "3: Type 'exit' to exit the Docker shell after installation"
    pretty_print "=============================="
    pretty_print "Thank you for using the quick helper script!"
    pretty_print "(you are now inside the Docker shell)"
    pretty_print " "

    # Running docker image
    docker run -e PROJECT_ID="${PROJECT_ID}" -v "$(pwd):/var/consumer-edge-install:ro" -it ${IMAGE_PATH}

    if [[ $? -gt 0 ]]; then
        pretty_print "ERROR: Docker container cannot open." "ERROR"
        exit 1
    fi

else
    echo "Aborting."
    exit 0
fi