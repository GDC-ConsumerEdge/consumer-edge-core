#/bin/bash

# Create n-number of GCE instances with named conventions to be picked up by Ansible

#### TODO: gcloud compute config-ssh  (on the host computer after GCEs are setup?)

unset GCE_COUNT
unset REGION_OVERRIDE
unset STARTING_INDEX

while getopts 'c:s:r:': option
do
    case "${option}" in
        c) GCE_COUNT=${OPTARG};;
        s) STARTING_INDEX="${OPTARG}";;
        r) REGION_OVERRIDE="${OPTARG}";;
    esac
done

usage()
{
  echo "Usage: $0 -c 1
            [ -r us-west1 ]
            [ -s 1 ]"
  exit 2
}

if [[ -z "${GCE_COUNT}" || ${GCE_COUNT} -le 0 ]]; then
    echo "Missing count variable"
    usage
    exit 0
fi

# Starting (used for offset starting)
# TODO: setup use of offset above
CLUSTER_START_INDEX=1

source ./gce-helper.vars

###############################
#####   MAIN   ################
###############################

# Create init script bucket for GCE instances to use
setup_init_bucket

copy_init_script

# Store the SSH pub key as a secret
store_public_key_secret ${SSH_PUB_KEY_LOCATION}

# Create the GCE instances
create_gce_vms

