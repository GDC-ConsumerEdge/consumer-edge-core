#!/bin/bash

# Use the path to this script to determine the path to gce-helper.vars
PREFIX_DIR=$(dirname -- "$0")
source "${PREFIX_DIR}/cloud/gce-helper.vars"

SSH_KEY="~/.ssh/cnuc.pub"
if [[ -f "./build-artifacts/consumer-edge-machine.pub" ]]; then
    SSH_KEY="./build-artifacts/consumer-edge-machine.pub"
fi

if [[ ! -z $1 ]]; then
    # any parameter passed will trigger ONLY the /etc/hosts format for cnucs
    display_ip_host_format
else
    display_gce_vms_ips "${SSH_KEY}"
fi