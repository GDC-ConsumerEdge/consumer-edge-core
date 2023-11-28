#!/bin/bash

SIDELOAD_IMAGES="/home/abm-admin/sideload-images" # from "sideload-push-remote.sh"

declare -a DOCKER_IMAGES=(
  "docker.io__redis---6.0.9-alpine.tar"
  # "docker.io__senthilrch__kubefledged-controller---v0.10.0.tar"
)

declare -a DOCKER_IMAGES=(
  "registry.k8s.io__sig-storage__csi-attacher---v4.2.0.tar"
  "registry.k8s.io__sig-storage__csi-node-driver-registrar---v2.6.3.tar"
  "registry.k8s.io__sig-storage__csi-provisioner---v3.4.1.tar"
  "registry.k8s.io__sig-storage__livenessprobe---v2.9.0.tar"
)

declare -a QUAY_IMAGES=(
  "quay.io__samba.org__samba-server---latest"
  "quay.io__samblade__virtvnc---v0.1"
)

echo ""
read -p "What Host do you want to push to (or ctrl+c to exit)? " host

if [[ -z "${host}" ]]; then
  echo "No host provided. Please provide a host."
  exit 1
fi

echo "Running on $host"

for image in "${DOCKER_IMAGES[@]}"; do
  ssh -F build-artifacts/ssh-config $host "sudo ctr -n=docker.io images import ${SIDELOAD_IMAGES}/$image --digests=true"
done

for image in "${K8S_IMAGES[@]}"; do
  ssh -F build-artifacts/ssh-config $host "sudo ctr -n=registry.k8s.io images import ${SIDELOAD_IMAGES}/$image --digests=true"
done

for image in "${QUAY_IMAGES[@]}"; do
  ssh -F build-artifacts/ssh-config $host "sudo ctr -n=quay.io images import ${SIDELOAD_IMAGES}/$image --digests=true"
done

ssh -F build-artifacts/ssh-config $host "sudo crictl images list"
