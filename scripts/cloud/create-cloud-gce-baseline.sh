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


# Create n-number of GCE instances with named conventions to be picked up by Ansible

#### TODO: gcloud compute config-ssh  (on the host computer after GCEs are setup?)

## Get directory this script was run from. gce-helpers.vars is in the same directory.
## -- is used in case the directory name starts with a -
PREFIX_DIR=$(dirname -- "$0")
WORKDIR=$(pwd)
BASE_DIR=$(basename $WORKDIR)
source ${PREFIX_DIR}/gce-helper.vars

# This script is likely to be run from two primary locations, so detecting that
# and sourcing the pretty print library. If this script is run from some other
# location, manually define pretty_print so this script doesn't fail.
if [ "$BASE_DIR" = "core" ]; then
  source scripts/install-shell-helper.sh
elif [ "$BASE_DIR" = "cloud" ]; then
  source ../install-shell-helper.sh
else
  pretty_print() { echo -e "$1"; }
fi

# Defaults
GCE_COUNT=1
CLUSTER_START_INDEX=1
unset PREEMPTIBLE_OPTION
SSH_PUB_KEY_LOCATION="${WORKDIR}/build-artifacts/consumer-edge-machine.pub" # default

while getopts 'c:p:k:v:s:tz:': option
do
    # #*= allows for c=1 and strips out the c= in addition to -c 1
    case "${option}" in
        c) GCE_COUNT="${OPTARG#*=}";;
        k) SSH_PUB_KEY_LOCATION="${OPTARG#*=}";;
        p) PROJECT_ID="${OPTARG#*=}";;
        s) CLUSTER_START_INDEX="${OPTARG#*=}";;
        t) PREEMPTIBLE_OPTION="--preemptible";;
        v) VXLAN_ID="${OPTARG#*=}";;
        z) ZONE="${OPTARG#*=}";;
    esac
done

usage()
{
    echo -e "\nUsage: $0
        [ -c NUM_INSTANCES ]
        [ -k SSH_PUB_KEY_LOCATION ]
        [ -p PROJECT_ID]
        [ -s STARTING_INDEX ]
        [ -v VXLAN ID ]
        [ -t ]
        [ -z ZONE ]"
    echo "-c: Number of instances to create. Defaults to 1. Example: -c 1"
    echo "-k: SSH public key location. Defaults to './build-artifacts/consumer-edge-machine.pub'. Creates the key if it doesn't exist."
    echo "-p: project ID. Can be set with PROJECT_ID environment variable. Defaults to gcloud config if not set."
    echo "-s: Starting index. Defaults to 1. Example: -s 10."
    echo "-v: VXLAN ID (default 40)"
    echo "-t: Use temporary preemptible instances."
    echo "-z: Zone. Can be set with ZONE environment variable. Defaults to gcloud config zone if not set."
    exit 2
}


###
###  Create and/or store public key used in ansible provisioning (ie, the "host" box)
###
function store_public_key_secret() {
    SSH_KEY_LOC=$1
    # Create SSH key if it doesn't exist
    create_ssh_key "${SSH_KEY_LOC}"

    create_secret "${SSH_KEY_SECRET_KEY}" "${SSH_KEY_LOC}" "true" # create the secret from a file
}

ERROR=0
if [[ ! -x $(command -v gcloud) ]]; then
    pretty_print "Error: gcloud (Google Cloud SDK) command is required, but not installed." "ERROR"
    ERROR=1
fi

if [[ ! -x $(command -v envsubst) ]]; then
    pretty_print "Error: envsubst (gettext) command is required, but not installed." "ERROR"
    ERROR=1
fi

if [[ ! -x $(command -v ssh-keygen) ]]; then
    pretty_print "Error: ssh-keygen (SSH) command is required, but not installed." "ERROR"
    ERROR=1
fi

if [[ "${ERROR}" -eq 1 ]]; then
    exit 1
fi

ERROR=0
# Default to gcloud if not set
if [[ -z "${PROJECT_ID}" ]]; then
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
fi

if [[ -z "${PROJECT_ID}" ]]; then
    pretty_print "Error: No project ID set" "ERROR"
    ERROR=1
fi

# Default to gcloud if not set
if [[ -z "${ZONE}" ]]; then
    ZONE=$(gcloud config get-value compute/zone 2>/dev/null)
fi

if [[ -z "${ZONE}" ]]; then
    pretty_print "Error: No zone set. Re-run this script with the -z option, or set \
a default zone with the gcloud CLI" "ERROR"
    ERROR=1
fi

if [[ -z "${GCE_COUNT}" || ! "${GCE_COUNT}" =~ ^[0-9]+$ || "${GCE_COUNT}" -le 0 ]]; then
    pretty_print "Error: Missing or invalid count variable" "ERROR"
    ERROR=1
fi

if [[ -z "${CLUSTER_START_INDEX}" || ! "${CLUSTER_START_INDEX}" =~ ^[0-9]+$ || "${CLUSTER_START_INDEX}" -le 0 ]]; then
    pretty_print "Error: Missing or invalid starting index" "ERROR"
    ERROR=1
fi

if [[ "${ERROR}" -eq 1 ]]; then
    usage
    exit 1
fi

# Check if md5 or md5sum is avail
md5bin=$(checkformd5)
if [[ -z "$md5bin" ]]; then
    pretty_print  "ERROR: I couldn't find md5 or md5sum, which I need. Exiting." "WARN"
    exit 1
fi

pretty_print "\nGCE_COUNT: ${GCE_COUNT}" "INFO"
pretty_print "PROJECT_ID: ${PROJECT_ID}" "INFO"
pretty_print "START_INDEX: ${CLUSTER_START_INDEX}" "INFO"
pretty_print "ZONE: ${ZONE}" "INFO"
pretty_print "GCE Prefix: ${GCE_NAME_PREFIX}" "INFO"
pretty_print "===========================================\n" "INFO"

if [[ ! -z "$PREEMPTIBLE_OPTION" ]]; then
    pretty_print "NOTE: USING PREEMPTIBLE MACHINE. The GCE will be up at most 24h and will need to be re-created and re-provisioned. This option keeps the costs of testing/trying ABM Retail Edge to a minimum" "INFO"
fi

# Check to make sure that the # of VMs is divisible by 3 (need 3 per location)
if [[ $((GCE_COUNT%REQUIRED_CLUSTER_SIZE)) != 0 ]]; then
    pretty_print "The count ( $GCE_COUNT ) requested CNUCs needs to be multiples of 3" "ERROR"
    exit 1
fi

CLUSTER_COUNT=$(( GCE_COUNT/REQUIRED_CLUSTER_SIZE ))
pretty_print "Final Cluster Count = $CLUSTER_COUNT" "INFO"

###############################
#####   MAIN   ################
###############################

# Setup firewalls for GCE VXLAN (only needed by cloud-version) #TODO: Modify this to use tags on the GCE instances

# Look for any firewall rules with "vxlan" in them (see below for vxlan firewall entries...this works for both rules)
FIREWALLS=$(gcloud compute firewall-rules list --filter=name=vxlan --format="value(name)")
if [[ -z "${FIREWALLS}" ]]; then
    gcloud compute firewall-rules create vxlan-egress \
        --allow all \
        --direction=EGRESS \
        --network=${NETWORK} \
        --priority=900

    gcloud compute firewall-rules create vxlan-ingress \
        --allow all \
        --direction=INGRESS \
        --network=${NETWORK} \
        --priority=900 \
        --source-ranges="10.0.0.0/8"
fi

# Create init script bucket for GCE instances to use
setup_init_bucket

# Copy the init script to bucket for GCE startup
copy_init_script

# Store the SSH pub key as a secret
store_public_key_secret ${SSH_PUB_KEY_LOCATION}

# Create the GCE instances
create_gce_vms $GCE_COUNT

display_gce_vms_ips

pretty_print "\nCheck the Cloud Init scripts: sudo journalctl -u google-startup-scripts.service\n"