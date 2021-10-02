#!/bin/bash

##
## This script is used to ping-pong (built-in ansible command) the inventory files
##

case "$1" in

    "NUC" | "nuc" | "workers" )
        GROUP="workers"
        echo "Checking only the local workers/NUCs"
        ;;

    "cloud" | "CLOUD" | "cloud_type_abm" )
        GROUP="cloud_type_abm"
        echo "Checking only the cloud instances"
        ;;

    "all")
        GROUP="all"
        ;;

    *)
        GROUP="all"
        ;;
    esac

CWD=$(pwd)
INVENTORY_DIR="./inventory"

if [[ "${CWD}" == *"/scripts"* ]]; then
    INVENTORY_DIR="../inventory"
fi

ansible ${GROUP} -i ${INVENTORY_DIR} -m ansible.builtin.ping --one-line
