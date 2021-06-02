#!/bin/bash

#TODO: run a script that unbundles ABM from GKE connect/kub

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
    INSTANCES=( $(gcloud compute instances list --format="value(name)") )
fi

for instance in "${INSTANCES[@]}"
do
    echo "Removing $instance..."
    gcloud compute instances delete ${instance} --zone ${ZONE} -q
done


