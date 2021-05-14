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


ansible ${GROUP} -i ../inventory -m ansible.builtin.ping --one-line
