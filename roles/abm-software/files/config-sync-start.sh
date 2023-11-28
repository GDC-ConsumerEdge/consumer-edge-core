#!/bin/bash

kubectl -n config-management-system scale deployment config-management-operator --replicas=1

