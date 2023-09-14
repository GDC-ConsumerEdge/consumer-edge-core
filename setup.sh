#!/bin/bash
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

# Run from inside of either CloudShell or a Bastion VM inside of the same GCP project as the GCP cnuc's

PREFIX_DIR=$(dirname -- "$0")
source ${PREFIX_DIR}/scripts/cloud/gce-helper.vars
source ${PREFIX_DIR}/scripts/install-shell-helper.sh

# Results in none or one key for the current Instance Run to download. If empty, no key to down
function get_downloadable_key_name {
	# NOTE: This matches Ansible's setting for ssh key download
	local SSH_SECRET_NAME_PREFIX="ssh-priv-key-"

	# First check if there is a key in the GCP Secret Manager
	SECRET_LIST=$(gcloud secrets list --filter="name~${SSH_SECRET_NAME_PREFIX}" --format="value(name)" --project="${PROJECT_ID}" 2> /dev/null)
  SECRET_COUNT=${#SECRET_LIST[@]}
  num=0

  # If no secrets are found, the SECRET_LIST variable will have a single item
  # which is an empty string. Catching that condition here
  if [ ${SECRET_COUNT} -ge 1 ] && [ ! -z ${SECRET_LIST[0]} ]; then
    pretty_print "\nThere are existing SSH private keys in Google Secret Manager for the project ${PROJECT_ID}. \n" "DEBUG"

    for index in ${!SECRET_LIST[@]}; do
          cluster_name=${SECRET_LIST[$index]#"$SSH_SECRET_NAME_PREFIX"}
          num=$(( index + 1 ))
      pretty_print "  $num) ${cluster_name}" "DEBUG"
    done
  else
    SECRET_COUNT=0
    pretty_print "No existing SSH private keys were found in Google Secret Manager
     for this project (${PROJECT_ID})" "DEBUG"
  fi

  # Add option for "create a new key"
	pretty_print "  $((num+1))) Create a new key-pair" "DEBUG"
	pretty_print "\n  Ctrl+C to cancel\n" "DEBUG"

  # Start capture of decision
	read -p "Which of these do you want to use: " sel_key_num

	if [[ "${sel_key_num}" =~ ^([1-9][0-9]*)$ ]] && [[ "${sel_key_num}" -le $((SECRET_COUNT+1)) ]] ; then
        if [[ "${sel_key_num}" -le SECRET_COUNT ]]; then

    		pretty_print "\nINFO: Downloading key for ${SECRET_LIST[$index]#}" "INFO"
            gcloud secrets versions access latest --secret="${SECRET_LIST[$index]}" >> ./build-artifacts/consumer-edge-machine --project="${PROJECT_ID}"
			chmod 600 ./build-artifacts/consumer-edge-machine
            pretty_print "INFO: Generate the public key locally ./build-artifacts/consumer-edge-machine.pub" "INFO"
            ssh-keygen -f ./build-artifacts/consumer-edge-machine -y >> ./build-artifacts/consumer-edge-machine.pub
        else
            echo "\nINFO: Creating a new SSH key-pair and pushing to Google Secret Manager for Cluster '${DEFAULT_CLUSTER_NAME}'"
            echo "INFO: The new primary key stored at ./build-artifacts/consumer-edge-machine.pub"

            ssh-keygen -o -a 100 -t ed25519 -f ./build-artifacts/consumer-edge-machine -N ''
            gcloud secrets create ssh-priv-key-${DEFAULT_CLUSTER_NAME} --replication-policy="automatic" > /dev/null 2>&1 # Ignore all issues with this
            gcloud secrets versions add ssh-priv-key-${DEFAULT_CLUSTER_NAME} --data-file="build-artifacts/consumer-edge-machine" > /dev/null 2>&1
        fi
    else
        pretty_print "\nERROR: The answer [${sel_key_num}] was not recognized, please re-run.\n" "ERROR"
        exit 1
	fi
}

# Option to add the cluster name to the script
DEFAULT_CLUSTER_NAME=${1:-cnuc-1}
if [[ "${DEFAULT_CLUSTER_NAME}" =~ ^([a-z]+[0-9a-z-]*)$ ]]; then
	pretty_print "INFO: Evaluating setup using cluster name [${DEFAULT_CLUSTER_NAME}]" "INFO"
else
	pretty_print "ERROR: Cluster name [$DEFAULT_CLUSTER_NAME] contains characters that cannot be used. Only lowercase alpha-numeric and dashes can be used" "ERROR"
	exit 1
fi

# Must currently run as an admin user with org permissions in order to make the changes throughout
# For now this means we will require that the user login via gcloud auth login
# This check will bail if a gserviceaccount is found in use
ACTIVE_USER=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
GSERVICEACCOUNT=$(echo ${ACTIVE_USER} | grep gserviceaccount)
if [[ ! -z "${GSERVICEACCOUNT}" ]]; then
	echo "Detected gcloud is authenticated using a GSA. Please login as a human user account using the following command -- 'gcloud auth login --no-launch-browser'"
	echo "Copy/Paste the link into a browser where you are authenticated with admin level permissions for the project!!"
	exit 1
fi

# detect Argolis user
ARGOLIS_USER=$(echo ${ACTIVE_USER} | grep "altostrat.com")
IS_ARGOLIS=false
if [[ ! -z "${ARGOLIS_USER}" || ! -z "${ARGOLIS_PROJECT}" ]]; then
	pretty_print "INFO: Detected this is an Argolis project and will attempt to modify org policies to enable Consumer Edge." "DEBUG"
	IS_ARGOLIS=true
fi

# If PROJECT_ID is not defined, prompt the user to define the project ID to use
if [[ -z "${PROJECT_ID}" ]]; then
  # If a project has been configured through gcloud, capture that
  GCLOUD_PROJECT=$(gcloud config list --format 'value(core.project)' 2>/dev/null)
  read -p "Enter the GCP Project ID to use for this installation [${GCLOUD_PROJECT}]: " selected_project
  PROJECT_ID=${selected_project:-$GCLOUD_PROJECT}
fi

pretty_print "\nBeginning installation, using ${PROJECT_ID} as the target GCP Project." "DEFAULT"

# Configure gcloud to use the selected GCP project
gcloud config set project ${PROJECT_ID} --no-user-output-enabled

# Needed for reference
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")

pretty_print "\nINFO: Enabling GCP services required for project" "INFO"

if [[ ${IS_ARGOLIS} == true ]]; then
	source ./scripts/argolis-setup.sh
fi

# Enable any services needed
gcloud services enable \
  servicemanagement.googleapis.com \
	anthos.googleapis.com \
  cloudbuild.googleapis.com \
	cloudresourcemanager.googleapis.com \
  serviceusage.googleapis.com \
	compute.googleapis.com \
  secretmanager.googleapis.com \
  --quiet --verbosity=critical --no-user-output-enabled

pretty_print "INFO: Adding roles/secretmanager.secretAccessor and roles/storage.objectViewer to default compute service account." "INFO"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor" --no-user-output-enabled

pretty_print "INFO: Adding roles/storage.objectViewer to default compute service account." "INFO"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
    --role="roles/storage.objectViewer" --no-user-output-enabled

pretty_print "INFO: Adding roles/storage.objectViewer to default cloudbuild service account." "INFO"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
    --role="roles/storage.objectViewer" --no-user-output-enabled

# Validate that required applications are installed
REQUIRED_APPS=(direnv docker gcloud gettext git jq screen)
MISSING_APPS=()
DOCKER_MISSING=0

echo ""
for app in ${REQUIRED_APPS[@]}; do
  if ! command -v $app > /dev/null 2>&1; then
    pretty_print "ERROR: ${app} is required, but not installed." "ERROR"
    # Docker won't be installed through apt, so catching that so we can manually
    # install docker later
    [ ${app} != "docker" ] && MISSING_APPS+=(${app}) || DOCKER_MISSING=1
  else
    pretty_print "PASS: ${app} is required and installed."
  fi
done

# If required software is missing, prompt the user to install
if [ ${#MISSING_APPS[@]} -gt 0 ]; then
  pretty_print "=========================" "ERROR"
	pretty_print "Some or all required dependencies are not met." "INFO"
	read -p "Would you like this script to install the required dependencies? (Y/N) " -n 1 -r
	echo
	if [[ "${REPLY}" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    pretty_print "\nInstalling ${MISSING_APPS[@]}.\n"
    sudo apt install -y ${MISSING_APPS[@]}
    pretty_print "Finished installing dependencies."
    pretty_print "\nPLEASE add: eval \"$(direnv hook bashrc)\" (or zsh) to your ~/.bashrc or ~/.zshrc file" "INFO"
  else
		pretty_print "\nExiting. Please fix dependencies on your own, or re-run this script and select 'Y'" "ERROR"
		exit 1
  fi
fi

# We're installing Docker through the Docker apt repo not through the distro's
# packages. If Docker is not installed, performing the install here
if [ ${DOCKER_MISSING} -eq 1 ]; then
  pretty_print "Installing docker" "INFO"

  sudo apt -y remove docker docker-engine docker.io containerd runc
  sudo apt -y install ca-certificates curl gnupg lsb-release
  curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --yes --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt update
  sudo apt -y install docker-ce docker-ce-cli containerd.io
  sudo usermod -aG docker $(whoami)
  sudo chmod 666 /var/run/docker.sock
  pretty_print "\nFinished Docker setup..." "INFO"
fi

# Enable mouse scroll and scrollback in screen configuration & session
echo "termcapinfo xterm* ti@:te@" > .screenrc

SSH_KEY_LOC="./build-artifacts/consumer-edge-machine"
# Setup SSH Keys on local box (create new or download from GCP Secret Manager)
if [[ ! -f "./build-artifacts/consumer-edge-machine" ]]; then
	get_downloadable_key_name
fi

# Print the public key (not sensitive)
PUB_KEY=$(cat ${SSH_KEY_LOC}.pub)
pretty_print "\nINFO: Public key-pair used: ${PUB_KEY}" "INFO"

export QL_PROJECT_ID=$(gcloud config get-value project 2> /dev/null)
if [[ -z "${QL_PROJECT_ID}" ]]; then
		pretty_print "ERROR: Project ID not configured for gcloud. Please set project with 'gcloud config set project <project-id>'" "ERROR"
        exit 1
	else
		pretty_print "INFO: Setting PROJECT_ID: ${PROJECT_ID}" "INFO"
		export PROJECT_ID="${QL_PROJECT_ID}"
fi

pretty_print ""
pretty_print "==============================="
pretty_print ""
pretty_print "All of the following variables CAN and SHOULD be verified in the generated 'envrc' file following the completion of this script"
pretty_print ""

export ROOT_REPO_URL="https://gitlab.com/gcp-solutions-public/retail-edge/primary-root-repo-template.git"
pretty_print "INFO: Setting default Primary Root Repo: ${ROOT_REPO_URL}" "INFO"

pretty_print "INFO: Setting up docker configuration to use gcloud for gcr.io" "INFO"
yes Y | gcloud auth configure-docker --quiet --verbosity=critical --no-user-output-enabled

if [[ ! -f "build-artifacts/envrc" ]]; then
	pretty_print "INFO: Generating 'envrc' properties file" "INFO"
	envsubst "${PROJECT_ID}" < templates/envrc-template.sh > build-artifacts/envrc
else
	pretty_print "PASS: Using existing envrc file"
fi
direnv allow .

if [[ ! -f "./build-artifacts/provisioning-gsa.json" ]]; then
	pretty_print "INFO: Create the provisioning GSAs used during initial setup. JSON key placed in ./build-artifacts/" "INFO"
	yes Y | ./scripts/create-gsa.sh
else
	pretty_print "PASS: GSA Keys have been created for the provisioning GSA"
fi

# Create docker container for building
CONTAINER_URL=$(gcloud container images list --repository=gcr.io/${PROJECT_ID} --format="value(name)" --filter="name~consumer-edge-install")
if [[ -z "$CONTAINER_URL" ]]; then
	pretty_print "INFO: This project uses a Docker image to provision host machines
  from. The image has not been detected and a build request has been submitted to
  GCP." "INFO"

  # This build is being submitted async, so this command will return ~immediately
  # while the container is being built by Cloud Build in the background.
	gcloud builds submit --config ./docker-build/cloudbuild.yaml ./ --async --quiet --verbosity=critical --no-user-output-enabled
else
	pretty_print "\nINFO: Docker build image was found, and will not be rebuilt." INFO
fi

if [[ ! -f "build-artifacts/gcp.yml" ]]; then
	pretty_print "INFO: Default GCP Ansible plugin configuration was not found. Generating a new version at build-artifacts/gcp.yml" "INFO"
	envsubst < templates/inventory-cloud-example.yaml > build-artifacts/gcp.yml
else
	pretty_print "PASS: GCP Inventory file found at build-artifacts/gcp.yml"
fi

pretty_print "\n\nYour project is set up and ready for use. You will need to do a combination of the following options next:\n"
pretty_print "1. Use your editor of choice and check the generated 'build-artifacts/envrc' file to ensure correct Environment Variables were set." "INFO"
pretty_print "2. If you made any changes, save file and run either: 'direnv allow .' or 'source build-artifacts/envrc'"

pretty_print "Cloud-based host machines (default)" "DEBUG"
pretty_print "1. Create GCE instances: run './scripts/cloud/create-cloud-gce-baseline.sh -c 3'" "INFO"

pretty_print "\nPhysical Machine based host machines" "DEBUG"
pretty_print "1. Copy the 3 'edge-X.yaml' files in ./inventory and rename with a hostname of your choice (ie: nucs-1.yaml, nucs-2.yaml, nucs-3.yaml)"
pretty_print "2. If using physical hardware, create an inventory file: envsubst < templates/inventory-physical-example.yaml > build-artifacts/inventory.yaml."
pretty_print "   - Modify this file to match your host_var inventory files (see previous step). Comment out 'edge-1,edge-2,edge-3 and replace with your host names"

pretty_print "\n==== Last Step ===\n1. Run: ./install.sh\n"
pretty_print "NOTE: Physical machines require a bit more setup not outlined here. Please ping the https://www.google.com/goto/gdc-consumer-edge:gchat team for more info.\n\n"
