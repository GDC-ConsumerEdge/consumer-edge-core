#!/bin/bash

echo "Looking for instances..."

INSTANCES=()
# By default, remove all GCE instances
if [[ ! -z "$1" ]]; then
    instance_name="$1"
    INSTANCE=$(gcloud compute instances list --filter="name~"$instance_name"" --format="value(name, zone)" 2>/dev/null ) # error goes to /dev/null
    if [[ -z "${INSTANCE}" ]]; then
        echo "${instance_name} does not exist in this project. Skipping..."
        exit 1
    fi
    INSTANCES+=$INSTANCE
else
    # get list of all CNUCs in the project
    LABELS="labels.type=abm"
    IFS=$'\r\n'
    INSTANCES+=($(gcloud compute instances list --filter="${LABELS}" --format="value(name, zone)" 2>/dev/null))
fi

echo -e "\nRemoving '${#INSTANCES[@]}' instances"

if [[ ${#INSTANCES[@]} -lt 1 ]]; then
    echo -e "\nNo instances found...\n"
    exit 0
fi

for instance in "${INSTANCES[@]}"
do
    # Convert to string array
    IFS=$' \t'
    inst=($instance)
    instance_name="${inst[0]}"
    instance_zone="${inst[1]}"
    echo -e "\nRemoving ${instance_name} in ${instance_zone}..."
    echo -e "  -- Removing GKE Hub Assignment"
    gcloud container hub memberships delete ${instance_name} --quiet --async 2> /dev/null
    echo -e "  -- Deleting instance"
    gcloud compute instances delete ${instance_name} --zone ${instance_zone} -q
    echo -e "  -- Done!\n"
done
