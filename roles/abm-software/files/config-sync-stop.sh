#!/bin/bash

kubectl scale -n config-management-system deployment config-management-operator --replicas=0 \
> && kubectl wait -n config-management-system --for=delete pods -l k8s-app=config-management-operator \
> && kubectl scale -n config-management-system deployment --replicas=0 --all \
> && kubectl wait -n config-management-system --for=delete pods --all
deployment.apps/config-management-operator scaled
