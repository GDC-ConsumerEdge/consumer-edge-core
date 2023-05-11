# Overview

> NOTE: This document is intended to be used for testing and non-production use. Longhorn is an Open Source application and is not covered by Google service.

Longhorn is an SDS (Software Defined Storage) engine used to manage stateful volumes in a K8s cluster.

## Installation

During provsioning, use the Cluster Trait Repository to install Longhorn into your system.

1. Add `storage_provider: longhorn` into your Inventory cluster-level configuration

    ```yaml
    ...
    edge_cluster:
        hosts:
            edge-1:
            node_ip: "192.168.3.11"
            ... removed for breveity ...
        vars:
            # Name of the cluster
            cluster_name: "edge-1"
            # Added Storage Provider #< ------ Add the following to your cluster-level configuration
            storage_provider: "longhorn"
            storage_provider_repo_url: "https://gitlab.com/gcp-solutions-public/retail-edge/available-cluster-traits/longhorn-anthos.git"
            storage_provider_repo_type: "unstructured"
            storage_provider_auth_type: "none"
    ...

    ```
1. Run provisioning as you normally would


## Existing cluster

TBD
