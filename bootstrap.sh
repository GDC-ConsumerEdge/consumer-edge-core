#!/bin/bash

# This file will bootstrap the secrets and ensure the environment variables
# required are available.  This is idempotent, but only needs to be run once

# Check ENV varaibles

HAS_ERROR="false"
if [[ -z ${PROJECT_ID} ]]; then
    echo "ERROR: PROJECT_ID is not defined"
    HAS_ERROR="true"
fi

if [[( -z "${LOCAL_GSA_FILE}" )  || ( ! -f "${LOCAL_GSA_FILE}" ) ]]; then
    echo "ERROR: LOCAL_GSA_FILE is not defined or does not point to a file"
    HAS_ERROR="true"
fi

if [[ -z ${REGION} ]]; then
    echo "ERROR: REGION is not defined"
    HAS_ERROR="true"
fi

if [[ -z ${ZONE} ]]; then
    echo "ERROR: ZONE is not defined"
    HAS_ERROR="true"
fi

if [[ -z ${SCM_TOKEN_USER} ]]; then
    echo "ERROR: SCM_TOKEN_USER is not defined"
    HAS_ERROR="true"
fi

if [[ -z ${SCM_TOKEN_VALUE} ]]; then
    echo "ERROR: SCM_TOKEN_USER is not defined"
    HAS_ERROR="true"
fi

# Create a secret for the SSH key
if [[ ! -x "$(command -v gcloud)" ]]; then
  echo "gcloud is required" >&2
  HAS_ERROR="true"
fi

if [[ "${HAS_ERROR}" == "true" ]]; then
    echo "Errors exist, please fix and re-run"
    exit 1
fi