#!/bin/bash

RAW="$(gcloud monitoring dashboards list --format='value(name)' --filter='labels=retail-edge')"

declare -a dashboards
dashboards=( $RAW )

for dash in "${dashboards[@]}"
do
    echo "Deleteing ${dash}"
    gcloud monitoring dashboards delete "$dash" --project="${PROJECT_ID}" --quiet
done
