#!/bin/bash

# This file will bootstrap the secrets and ensure the environment variables
# required are available.  This is idempotent, but only needs to be run once

# Check ENV varaibles
REQUIRED=("PROJECT_ID" "LOCAL_GSA_FILE" "REGION" "ZONE")

if [[ -z ${PROJECT_ID} ]]; then
    echo "ERROR: PROJECT_ID is not defined"
fi

if [[( -z "${LOCAL_GSA_FILE}" )  || ( ! -f "${LOCAL_GSA_FILE}" ) ]]; then
    echo "ERROR: LOCAL_GSA_FILE is not defined or does not point to a file"
fi

if [[ -z ${REGION} ]]; then
    echo "ERROR: REGION is not defined"
fi

if [[ -z ${ZONE} ]]; then
    echo "ERROR: ZONE is not defined"
fi

