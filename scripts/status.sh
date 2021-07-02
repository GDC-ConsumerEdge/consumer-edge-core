#!/bin/bash

# Use the path to this script to determine the path to gce-helper.vars
PREFIX_DIR=$(dirname -- "$0")
source ${PREFIX_DIR}/gce-helper.vars

display_gce_vms_ips
