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


# This script downloads the Robin CLI tool to the local machine. Use in conjunction with "robin-signin-current.sh" to automate the sign-in process

### NOTE: This is meant to be called on-demand due to ephemeral nature of "master.robin-server.service.robin" not being in /etc/hosts or discoverable

# 1. kubectl get svc robin-console-ui -n robinio -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
# 2. curl -k 'https://${SERVICE_IP}:29442/api/v3/robin_server/download?file=robincli&os=linux' -o robin-client
# 3. chmod +x ./robin-client
# 4. mv ./robin-client /usr/local/bin

if [[ -f "/usr/local/bin/robin" ]]; then
    # "Robin client already exists, no need to proceed" (no output so-as to not load up the logs)
    exit 0
fi

if [[ $EUID != 0 ]]; then
    echo "This script needs to be run as escalated privledges (root/sudo)"
    exit 1
fi

# If kubeconfig is defined, go with that, if not use the path given
KUBECONFIG=${KUBECONFIG:-/var/abm-install/kubeconfig/kubeconfig}

# get the IP of the Loadbalaced Service
SERVICE_IP=$(kubectl get svc robin-console-ui -n robinio -o jsonpath='{.status.loadBalancer.ingress[0].ip}' --kubeconfig="${KUBECONFIG}")

# Make sure we have the IP
if [[ ! -n "${SERVICE_IP}" ]] || [[ -z "${SERVICE_IP}" ]]; then
    echo -e "ERROR: Service 'robin-console-ui' was not found in 'robinio' namespace. Abnormally exiting."
    exit 1
fi

# Pull the client from the running service, timout is 2 minutes
curl -s -t 120 -k "https://${SERVICE_IP}:29442/api/v3/robin_server/download?file=robincli&os=linux" -o robin-client

# make sure it is executable
chmod +x robin-client
# Move it to usr-bin so it can be access on the path
mv robin-client /usr/local/bin/robin
