#!/bin/bash

HOLD_DIR="/tmp/sideload-images"
mkdir -p ${HOLD_DIR}

declare -a IMAGES=(
  "docker.io/redis:6.0.9-alpine"
  "registry.k8s.io/sig-storage/livenessprobe:v2.9.0"
  "registry.k8s.io/sig-storage/csi-provisioner:v3.4.1"
  "registry.k8s.io/sig-storage/csi-node-driver-registrar:v2.6.3"
  "registry.k8s.io/sig-storage/csi-attacher:v4.2.0"
  "docker.io/senthilrch/kubefledged-controller:v0.10.0"
  "quay.io/samba.org/samba-server:latest"
  "quay.io/samblade/virtvnc:v0.1"
)

function encodeName(){
  current=$1

  # swap out "/" for "__" in the name
  current=$(echo "${current}" | sed "s|/|__|g")

  # swap out ":" for "---" in the name
  current=$(echo "${current}" | sed "s|:|---|g")

  echo $current
}

for image in "${IMAGES[@]}"; do
  echo "Pulling image $image"
  result=$(docker pull $image)
  if [[ $? -ne 0 ]]; then
    echo "Failed to pull $image"
    continue
  fi

  name=$(encodeName $image)

  echo "$name"
  # save the image
  docker save $image -o "${HOLD_DIR}/${name}.tar"
done
