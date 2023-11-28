#!/bin/bash

SIDELOAD_IMAGES="/home/abm-admin/sideload-images"
HOLD_DIR="/tmp/sideload-images" # copied from sideload-pull-local.sh

# TODO: Move this to a common.sh file or something like that to not repeat
# Derived from the sideload-pull-local.sh script (future is to just get listing of the HOLD_DIR and work from that)
declare -a IMAGES=(
    "docker.io__redis---6.0.9-alpine.tar"
    "docker.io__senthilrch__kubefledged-controller---v0.10.0.tar"
    "registry.k8s.io__sig-storage__csi-attacher---v4.2.0.tar"
    "registry.k8s.io__sig-storage__csi-node-driver-registrar---v2.6.3.tar"
    "registry.k8s.io__sig-storage__csi-provisioner---v3.4.1.tar"
    "registry.k8s.io__sig-storage__livenessprobe---v2.9.0.tar"
    "quay.io__samba.org__samba-server---latest"
    "quay.io__samblade__virtvnc---v0.1"
)

echo ""
read -p "What Host do you want to push to (or ctrl+c to exit)? " host

if [[ -z "${host}" ]]; then
    echo "No host provided. Please provide a host."
    exit 1
fi

echo "Pushing images to $host"

ssh -F build-artifacts/ssh-config $host "mkdir -p ${SIDELOAD_IMAGES}"

for image in "${IMAGES[@]}"; do
  echo "Copying image $image"
  scp -F build-artifacts/ssh-config "${HOLD_DIR}/${image}" "$host:${SIDELOAD_IMAGES}/${image}"
done