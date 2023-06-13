#!/bin/bash
# Copyright 2023 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


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
