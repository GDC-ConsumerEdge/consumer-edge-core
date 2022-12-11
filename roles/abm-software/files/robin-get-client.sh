#!/bin/bash

# This script downloads the Robin CLI tool to the local machine. Use in conjunction with "robin-signin-current.sh" to automate the sign-in process

### NOTE: This is meant to be called on-demand due to ephemeral nature of "master.robin-server.service.robin" not being in /etc/hosts or discoverable

# 1. kubectl get svc robin-admin -n robinio -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
# 2. curl -k 'https://${SERVICE_IP}:29442/api/v3/robin_server/download?file=robincli&os=linux' -o robin-client
# 3. chmod +x ./robin-client
# 4. mv ./robin-client /usr/local/bin

if [[ -f "/usr/local/bin/robin" ]]; then
    # "Robin client already exists, no need to proceed" (no output so-as to not load up the logs)
    exit 0
fi

# If kubeconfig is defined, go with that, if not use the path given
KUBECONFIG=${KUBECONFIG:-/var/abm-install/kubeconfig/kubeconfig}

# get the IP of the Loadbalaced Service
SERVICE_IP=$(kubectl get svc robin-admin -n robinio -o jsonpath='{.status.loadBalancer.ingress[0].ip}' --kubeconfig="${KUBECONFIG}")

# Make sure we have the IP
if [[ ! -n "${SERVICE_IP}" ]] || [[ -z "${SERVICE_IP}" ]]; then
    echo -e "ERROR: Service password does not exist in K8s Sercret 'login-secret' for 'robinio' namespace. Exiting"
    exit 1
fi

# Pull the client from the running service
curl -s -k "https://${SERVICE_IP}:29442/api/v3/robin_server/download?file=robincli&os=linux" -o robin-client
# make sure it is executable
chmod +x robin-client
# Move it to usr-bin so it can be access on the path
mv robin-client /usr/local/bin/robin
