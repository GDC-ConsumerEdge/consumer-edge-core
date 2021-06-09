#!/bin/bash

## Determine if running from project root or from within the "script/" folder
CWD=$(pwd)
PREFIX_DIR="./scripts"

if [[ "${CWD}" == *"/scripts"* ]]; then
    PREFIX_DIR="./"
fi

source ${PREFIX_DIR}/gce-helper.vars

display_gce_vms_ips