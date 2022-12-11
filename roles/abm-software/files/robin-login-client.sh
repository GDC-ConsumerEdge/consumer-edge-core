#!/bin/bash

KUBECONFIG=${KUBECONFIG:-/var/abm-install/kubeconfig/kubeconfig}


if [[ ! -f "/usr/local/bin/robin" ]]; then
    echo "ERROR: Robin client is not present. Run /usr/local/bin/robin-get-client.sh as privileged user (ie: sudo)"
    exit 1
fi

SERVICE_PASSWORD=$(kubectl -n robinio get secret login-secret -o jsonpath='{.data.password}' --kubeconfig="${KUBECONFIG}" | base64 -d)

if [[ ! -n "${SERVICE_PASSWORD}" ]] || [[ -z "${SERVICE_PASSWORD}" ]]; then
    echo -e "ERROR: Service LoadBalancer IP does not exist in 'robinio' namespace for 'robin-admin'. Exiting"
    exit 1
fi

# Logging in as admin
robin login admin --password "${SERVICE_PASSWORD}"
# Quick context on login status
robin whoami
