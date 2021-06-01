#!/bin/bash

case "$1" in

    "NUC" | "nuc" )
        GROUP="workers"
        ;;

    "cloud" | "CLOUD" | "cloud_type_abm" )
        GROUP="cloud_type_abm"
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

echo $INVENTORY_DIR

ansible ${GROUP} -i ${INVENTORY_DIR} -m ansible.builtin.ping --one-line
