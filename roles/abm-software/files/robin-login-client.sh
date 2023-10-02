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


KUBECONFIG=${KUBECONFIG:-/var/abm-install/kubeconfig/kubeconfig}
# TODO: Make this more dynamic, search for secrets with either `robin-login` or `robin-admin` or `default-admin-user`
ROBIN_SECRET_NAME="default-admin-user"

if [[ ! -f "/usr/local/bin/robin" ]]; then
    echo "ERROR: Robin client is not present. Run /usr/local/bin/robin-get-client.sh as privileged user (ie: sudo)"
    exit 1
fi

ROBIN_LOGIN_PASSWORD=$(kubectl -n robinio get secret ${ROBIN_SECRET_NAME} -o jsonpath='{.data.password}' --kubeconfig="${KUBECONFIG}" | base64 -d)

if [[ ! -n "${ROBIN_LOGIN_PASSWORD}" ]] || [[ -z "${ROBIN_LOGIN_PASSWORD}" ]]; then
    echo -e "ERROR: Secret for Default Admin Login does not exist in 'robinio' namespace for Exiting in error"
    exit 1
fi

# Get the IP of the Loadbalaced Service (If provided and available)
SERVICE_IP=$(kubectl get svc robin-console-ui -n robinio -o jsonpath='{.status.loadBalancer.ingress[0].ip}' --kubeconfig="${KUBECONFIG}")

if [[ -z "${SERVICE_IP}" ]]; then
    # Default, Get the IP of the current Robin Master
    SERVICE_IP=$(kubectl get pod -n robinio -l robin.io/robinrole=master -o jsonpath='{.items[0].status.hostIP}')
fi

# This should always work, it will overwrite the existing IF it exists
robin client add-context $SERVICE_IP --port 29442 --file-port 29445 --event-port 29449 --set-current

# Logging in as admin
robin login admin --password "${ROBIN_LOGIN_PASSWORD}"
# Quick context on login status
robin whoami
