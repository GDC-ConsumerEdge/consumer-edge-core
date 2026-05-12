#!/bin/bash
source scripts/instance-context.sh >/dev/null 2>&1
function gsm_put() { echo "MOCK PUT: \$@"; }
function gsm_get() { echo ""; }
# Provide 2 empty inputs for ssh_key
# The output will be the string echoed
get_secret "ssh_key" "mock-gsm" "true" "p" "r" "c" << INP


INP
