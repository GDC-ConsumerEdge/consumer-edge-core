# Overview

This is a group of playbooks and ansible tools/scripts to provision and manage Anthos Bare Metal on a given inventory list (SSH addressable servers)

## Provision

The following steps include one-time and repeatable steps to provision the ***target machine(s)***

1. Clone or Fork this repository
1. Create or review Google Servie Account
    1. Run `scripts/create-primary-gsa.sh` to create or enable a GSA used on the ***target machine(s)*** and generate the key
1. Review and run the [one-time setup](docs/ONE_TIME_SETUP.md)
1. Setup `inventory.yml` file to match your environment

## Terms

> **Target machine(s)** - The machine that the cluster is being installed into/onto (ie, NUC, GCE, etc)

> **Provisioning box** - The machine that initiates the `ansible` run. Typically a laptop or cloud-console if GCE (must be able to reach target machines)


## Installing Anthos Bare Metal

The Ansible script installs Ansible Bare Metal on all of the inventory hosts.

You will need to define 3 Environment Variables, as well as making any environment-specific change (like IP ranges)

### Required Environment Variables

| Environment Variable | Required | Description | Default Value |
|:---------------------|:--------:|:------------|:-------------:|
| LOCAL_GSA_FILE¹      |  Y       |  Google Service Account key to a GSA that is used to provision and activate all Google-based services (all `gcloud` commands) from inside the Target machine(s) | N/A |
| PROJECT_ID           |  Y       |  Google Project ID to put clusters, Service Accounts and API services into | N/A |
| REGION               |  N       |  Google default region | us-central1 |
| ZONE                 |  N       |  Google default zone | us-central1-a |

¹ - GSA Permissions should include: Editor (roles/editor) or Owner (roles/owner), and Storage Object Viewer (roles/storage.objectViewer) (NOTE: This is not necessarily the minimal-roles, further work will refine this). Please use `scripts/create-primary-gsa.sh` to generate the GSA and key if unfamilar on how to do this.

### Environment IPs

* control_plane_vip -- IP address that is addressable & available, not overlapping with other clusters, but not pre-allocated. This is created during the process
* ingress_vip -- Must be in the Load Balancer pool for the cluster, same rules as control_plane_vip for availability
* load_balancer_pool_cidr -- IP addresses for the LoadBalancers (bundled mode) can attach to, same rules as control_plane_vip
* control_plane_ip -- different than the `control_plane_vip`, this is the IP of the box you are installing on

> NOTE: The default inventory file sets up 9 LBs allocated per cluster, with 1 taken for Ingress (sufficient for POC and basic work)

### Running Ansible Install

> NOTE: Be sure to copy/clone the `inventory.yml` file and verify variables are acceptable for YOUR environment. Watch out for Docker and KIND IP overlaps if changing the service or pod CIDR blocks

```bash
ansible-playbook -K -i inventory.yml abm_standalone.yml
```

## Update/Upgrade OS

Equivalent of `apt-get update && apt-get upgrade` and `gcloud components update` (both without requiring human input)

```bash
# Update all servers ()
ansible-playbook -K -i group_a.yml update-servers.yml
```


## Little helpers

1. Remove ACM. NOTE: This hangs because the K8s API hangs due to namespace existing in listing but not existing in cluster. Cancel after about 30 seconds (ctrl+c) and re-run to verify gone. (not going to provide the 'dump-to-file, patch, run patch' fix here)

```bash
ansible workers -i inventory.yml --become -m shell -a "export KUBECONFIG=/var/kubeconfig/kubeconfig && kubectl delete -f /var/acm-configs/config-management-operator.yaml" -K
```

1. Create `git-creds` for the namespaces (FUTURE: this will be handled with `ExternalSecrets` and Secrets Manager)

```bash
    kubectl create secret generic git-creds --from-literal=username=${SCM_TOKEN_USER} --from-literal=token=${SCM_TOKEN_TOKEN} --namspace="xyz" # xyz = namespace
```