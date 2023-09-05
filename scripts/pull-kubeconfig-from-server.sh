#!/bin/bash

## NOTE: This is only used for physical machines, not GCP based VMs

echo "If you are using 'kubectx' you will want to delete the cluster profiles before running this script so-as to not overlap keys."

HOST="edge-1"

## Backup current kubeconfig
cp ~/.kube/config ~/.kube/config-backup

## Removely pull kubeconfig

scp -F ./build-artifacts/ssh-config ${HOST}:/var/abm-install/kubeconfig/kubeconfig ./build-artifacts/kubeconfig-${HOST}

## setup local kubeconfig to point to both
export KUBECONFIG=~/.kube/config:./build-artifacts/kubeconfig-${HOST}

# Flatten to one file
kubectl config view --flatten > ./all-in-one-kubeconfig.yaml

mv ./all-in-one-kubeconfig.yaml ~/.kube/config

