#!/bin/bash

echo "Looking for instances..."

INSTANCES=()
# By default, remove all GCE instances
if [[ ! -z "$1" ]]; then
    instance_name="cnuc-$1"
    EXISTS=$(gcloud compute instances list $instance_name 2>/dev/null ) # error goes to /dev/null
    if [[ -z "${EXISTS}" ]]; then
        echo "${instance_name} does not exist in this project. Skipping..."
        exit 0
    fi
    INSTANCES+=( "${instance_name}" )
else
    # get list of all CNUCs in the project
    LABELS="labels.type=abm"
    INSTANCES+=($(gcloud compute instances list --zones "${ZONE}" --filter="${LABELS}" --format="value(name)" 2>/dev/null))
fi

echo -e "\nRemoving '${#INSTANCES[@]}' instances"

if [[ ${#INSTANCES[@]} -lt 1 ]]; then
    echo -e "\nNo instances found...\n"
    exit 0
fi

for instance in "${INSTANCES[@]}"
do
    echo -e "\nRemoving $instance..."
    echo -e "  -- Removing GKE Hub Assignment"
    gcloud container hub memberships delete ${instance} --quiet --async 2> /dev/null
    echo -e "  -- Deleting instance"
    gcloud compute instances delete ${instance} --zone ${ZONE} -q
    echo -e "  -- Done!\n"
done


