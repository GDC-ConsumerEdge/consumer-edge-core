#!/bin/bash

### This script is used to SSH tunnel a remote K8s cluster's Service via IP to localhost

CWD=$(pwd)

if [[ -f "${CWD}/scripts" ]]; then
    echo "Please run this script from the root of the project (ie: ./scripts/forward-tunnel.sh)"
    exit 1
fi

read -p "What is the IP of the service on the remote K8s cluster? (ie: 10.200.0.52) " cluster_ip
read -p "What is the port of the remote service? (ie: 8001) " cluster_port
read -p "What local port would you like to use? (ie: 8001) " local_port
read -p "What hostname to use? (ie: cnuc-1) " host

KUBE_SERVICE_IP="${cluster_ip:="10.200.0.52"}"
KUBE_SERVICE_PORT="${cluster_port:="8001"}"
REMOTE_PORT="${local_port:="8001"}"
REMOTE_HOST="${host:="cnuc-1"}"

echo "Setting up service forward from ${host}: $cluster_ip:$cluster_port -> $local_port"
ssh -F "${CWD}/build-artifacts/ssh-config" "${REMOTE_HOST}" -NL \
        "${REMOTE_PORT}:${KUBE_SERVICE_IP}:${KUBE_SERVICE_PORT}"
