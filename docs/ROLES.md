# Ansible Roles Summary

This document provides a summary of the Ansible roles used in this project, detailing their primary goals, the tasks they perform, and the variables they define or use.

## Roles Overview

1. [download-ssh-key](#download-ssh-key)
2. [validate](#validate)
3. [set-proxy](#set-proxy)
4. [google-tools](#google-tools)
5. [gcp-setup](#gcp-setup)
6. [ready-linux](#ready-linux)
7. [setup-kvm](#setup-kvm)
8. [abm-install](#abm-install)
9. [abm-software](#abm-software)
10. [abm-post-install](#abm-post-install)
11. [ansible-pull](#ansible-pull)
12. [abm-login-token](#abm-login-token)
13. [coral-tpu-install](#coral-tpu-install)
14. [nvidia-drivers-install](#nvidia-drivers-install)
15. [abm-remove](#abm-remove)
16. [cleanup](#cleanup)
17. [gdce-provision](#gdce-provision)
18. [pre-cache-binaries](#pre-cache-binaries)
19. [reset-logs](#reset-logs)

---

### download-ssh-key
**Primary Goal:** Downloads the SSH private key from Secret Manager for local Ansible use.

**Ordered Tasks:**
1. Check for the secret in Secret Manager.
2. Download the latest version of the SSH private key.
3. Set appropriate file permissions (0600).
4. Add the key to the local `ssh-agent`.

**Variables:**
- **Used from `all.yml`:** `ansible_ssh_private_key_file`, `ansible_ssh_priv_key_secret`, `google_secret_project_id`, `primary_cluster_machine`, `ansible_ssh_key_timeout`.

---

### validate
**Primary Goal:** Validates all required environment variables, licenses, and hardware specs before provisioning begins.

**Ordered Tasks:**
1. Verify node IP connectivity.
2. Validate existence of required GCP and SCM environment variables.
3. Check GCP Project name length compatibility.
4. Verify Robin SDS license and bundle existence (if enabled).
5. Ensure filesystems meet minimum size requirements.
6. Check for mutually exclusive feature flags (e.g., VMRuntime vs Multus).
7. Validate OIDC configuration if enabled.
8. Ensure all hosts in play are active.

**Variables:**
- **Defined in `vars/main.yml`:** `fs_size_required`.
- **Used from `all.yml`:** `cluster_name`, `node_ip`, `acm_root_repo`, `google_project_id`, `google_region`, `google_zone`, `provisioning_gsa_key`, `node_gsa_key`, `longest_gca_name`, `storage_provider`, `storage_cluster_trait_repo_install`, `robin_gcp_secret_name`, `google_secret_project_id`, `robin_license_local_uri`, `robin_install_bundle_file`, `scm_token_user`, `scm_token_token`, `root_repository_git_auth_type`, `enable_vmruntime`, `enable_multus_network`, `enable_oidc`, `oidc_client_id`, `oidc_client_secret`, `oidc_user`, `ansible_play_hosts_all`, `ansible_play_hosts`.

---

### set-proxy
**Primary Goal:** Sets system-wide environment variables and application configurations for proxies.

**Ordered Tasks:**
1. Setup `.curlrc` with proxy settings.
2. Set `HTTP_PROXY`, `HTTPS_PROXY`, and `NO_PROXY` in `/etc/environment`.
3. Configure `snap` to use the defined proxies.

**Variables:**
- **Defined in `vars/main.yaml`:** `curl_home`, `proxy_no_proxy_default_ips`.
- **Used from `all.yml`:** `proxy_has_http_proxy`, `proxy_has_https_proxy`, `proxy_http_full_addr`, `proxy_https_full_addr`, `proxy_no_proxy_list`, `node_ip`.

---

### google-tools
**Primary Goal:** Installs Google Cloud SDK and related Kubernetes tooling on target machines.

**Ordered Tasks:**
1. Create directories for keys and tools.
2. Copy provisioning and node GSA keys to the node.
3. Download and install `gcloud` SDK.
4. Install `kubectx` and `kubens` utilities.
5. Install `kubectl`, `nomos`, `kustomize`, `gsutil`, and other components via `gcloud`.
6. Setup environment variables for GSAs and PATH.
7. Configure bash completion for gcloud and kubectl.
8. Authenticate the provisioning GSA for the current session.
9. Configure default region, zone, and proxies for gcloud.
10. Install `bmctl` and `ncgctl` binaries.
11. Install optional utilities like `k9s`, `kubestr`, and `virtctl`.

**Variables:**
- **Defined in `vars/main.yml`:** `gcloud_version`, `kubectx_version`, `k9s_version`, `kubestr_version`.
- **Used from `all.yml`:** `target_os`, `remote_keys_folder`, `provisioning_gsa_key`, `node_gsa_key`, `tools_base_path`, `optional_tools`, `google_project_id`, `google_region`, `google_zone`, `proxy_has_http_proxy`, `proxy_http_addr`, `proxy_http_port`, `proxy_http_user`, `proxy_http_pass`, `force_tools_upgrade`, `bmctl_version`, `ncgctl_version`.

---

### gcp-setup
**Primary Goal:** Configures GCP infrastructure dependencies like APIs, GSAs, and GCS buckets.

**Ordered Tasks:**
1. Enable required Google Cloud services.
2. Create or enable Google Service Accounts with appropriate IAM roles.
3. Manage GSA keys in Secret Manager and download them.
4. Enable ACM API in the fleet.
5. Create GCS bucket for cluster snapshots.
6. Setup SDS-specific GCP resources (buckets, secrets, HMAC keys).

**Variables:**
- **Used from `all.yml`:** `gcp_services_required`, `google_project_id`, `primary_cluster_machine`, `snapshot_gcs_bucket_base`, `storage_provider`, `service_accounts`, `google_secret_project_id`, `remote_keys_folder`, `storage_provider_auth_secret`, `scm_token_token`, `scm_token_user`, `storage_provider_gcs_bucket_name`, `storage_provider_hmac_gcm_secret`.

---

### ready-linux
**Primary Goal:** Baselines the Linux OS with required dependencies, users, and system configurations for ABM.

**Ordered Tasks:**
1. Configure HTTP/HTTPS proxies for apt/yum.
2. Install common system dependencies (curl, wget, etc.).
3. Update inotify watchers for high-density pod workloads.
4. Setup time synchronization and timezone.
5. Disable apparmor and ufw (Ubuntu).
6. Create the ABM installation user and setup passwordless sudo.
7. Configure node-to-node SSH access.
8. Install and configure Docker runtime.
9. Setup VLAN interfaces (if physical).
10. Configure log rotation.
11. Load required kernel modules (`tcm_loop`, `nfs`).
12. Disable multipath services if not needed.
13. Setup cron jobs for system and gcloud updates.
14. Populate `/etc/hosts` with peer node information.

**Variables:**
- **Defined in `vars/main.yml`:** `prinetint`, `docker_service_path`, `gcloud_update_cron_value`, `gcloud_update_log`, `automatic_update_update_time`, `automatic_update_upgrade_time`.
- **Used from `all.yml`:** `proxy_has_http_proxy`, `proxy_http_full_addr`, `proxy_has_https_proxy`, `proxy_https_full_addr`, `target_os`, `abm_install_folder`, `ansible_user`, `machine_timezone`, `timesync_servers`, `abm_install_user`, `ssh_key_name`, `ssh_user_home`, `is_cloud_resource`, `setup_vlan`, `storage_provider`, `cloud_vxlan_hosts`, `enable_multipath_service`, `node_ip`, `default_retry_count`, `default_retry_delay`, `ansible_distribution`, `ansible_distribution_release`, `ansible_default_ipv4.interface`.

---

### setup-kvm
**Primary Goal:** Installs KVM and libvirt for virtualization support.

**Ordered Tasks:**
1. Install KVM and libvirt dependencies.
2. Enable and start `libvirtd` service.
3. Configure qemu to run as root.
4. Enable `vhost_net` kernel module.
5. Create local system image directories.

**Variables:**
- **Defined in `vars/main.yml`:** `libvirt_home`, `image_base_dir`.
- **Used from `all.yml`:** `target_os`.

---

### abm-install
**Primary Goal:** Installs Anthos Bare Metal (ABM) onto a "ready" machine or VM, including user creation, key management, and cluster creation.

**Ordered Tasks:**
1. Fail if the number of available hosts does not match the expected count.
2. Create storage provider root folders.
3. Create Local PVC folder.
4. Create isolated install folder for the cluster.
5. Template cluster configuration file (`cluster-config.yaml.j2`).
6. Check if ABM is already registered in GKE Hub.
7. Set installation fact based on registration status.
8. Re-run VXLAN setup (for cloud resources).
9. Run VXLAN status check (for cloud resources).
10. Validate configuration using `bmctl check config`.
11. Create cluster using `bmctl create cluster`.
12. Re-gather Ansible facts.
13. Verify GKE Hub membership.
14. Create shared kubeconfig folder.
15. Share kubeconfig with other nodes in the cluster.
16. Setup `profile.d` for kubeconfig environment variables.

**Variables:**
- **Defined in `vars/main.yml`:** `edge_api_enabled`, `edge_api_location`, `abm_install_user`, `install_type`, `multi_network_enabled`, `enable_stackdriver_customer_app_logging`, `enable_cloudops_customer_app_logging`, `enable_google_managed_prometheus_customer_app_metrics`, `skip_preflight`, `pod_cidr`, `services_cidr`, `local_pvc_mount`, `local_share_pvc_mount`, `container_runtime`, `abm_install_sync_timeout_seconds`, `abm_install_sync_poll_seconds`.
- **Used from `all.yml`:** `ansible_play_hosts_all`, `ansible_play_hosts`, `storage_provider_roots`, `storage_provider`, `abm_workspace_folder`, `cluster_name`, `is_cloud_resource`, `abm_install_folder`, `remote_keys_folder`, `google_project_id`, `kubeconfig_shared_root`, `target_os`, `peer_node_ips`, `node_ip`, `kubeconfig_shared_location`, `ssh_key_path`, `service_accounts`, `abm_version`.

---

### abm-software
**Primary Goal:** Installs and configures software layers on top of ABM, such as ACM, SDS (Robin/Longhorn), and Network Connectivity Gateway.

**Ordered Tasks:**
1. Add Fleet Cluster Labels.
2. Verify SCM environment variables.
3. Create cluster snapshot.
4. Remove taints from master node.
5. Install VMRuntime components.
6. Setup Stackdriver AddOnConfiguration.
7. Install Anthos Config Management (ACM) Operator and root repo.
8. Configure External Secrets operator and secret stores.
9. Setup SDS (Software Defined Storage) - Robin or Longhorn.
10. Install Anthos Network Connectivity Gateway (NCG).
11. Add Legacy CPU Monitor KubeVirt service files.
12. Setup OIDC authentication in the cluster.

**Variables:**
- **Defined in `vars/main.yml`:** `root_repository_service_account_email`, `root_repository_git_secret_name`, `cdi_staging_project`, `snapshot_config_folder`, `snapshot_config_file`, `snapshot_output_folder`, `cdi_cron_script_file`, `sds_config_files`, `robin_lvm_group_name`, `robin_license_file_location`, `robin_install_bundle_file`, `robin_install_folder`, `robin_acm_secret_name`, `robin_client_retries`, `robin_client_delay`.
- **Used from `all.yml`:** `cluster_name`, `google_project_id`, `remote_keys_folder`, `scm_token_user`, `scm_token_token`, `primary_cluster_machine`, `root_repository_git_auth_type`, `kubeconfig_shared_location`, `enable_vmruntime`, `vmruntime_config_path`, `kubevirt_use_emulation`, `disable_cdi_upload_proxy_vip`, `enable_google_managed_prometheus_customer_app_metrics`, `storage_provider`, `network_connectivity_gateway_install`, `cpu_monitor_install`, `enable_oidc`, `tools_base_path`, `ncgctl_version`, `google_secret_project_id`, `acm_config_files`, `acm_root_repo`, `root_repository_branch`, `root_repository_sync_time`, `root_repository_policy_dir`, `acm_root_repo_structure`, `acm_ssh_private_keyfile`, `primary_root_sync_name`, `default_retry_count`, `default_retry_delay`, `use_workload_identity_for_external_secrets`, `abm_install_folder`.

---

### abm-post-install
**Primary Goal:** Performs post-installation activities including bugfixes, observability setup, and cluster validation.

**Ordered Tasks:**
1. Update `metrics-server` resources (for ABM versions < 1.14.2).
2. Install and configure `Kube PS1` for shell users.
3. Setup automated certificate rotation cron job.
4. Add CDI required `cpumanager` label for nodes.
5. Patch `gke-connect` deployment resources.
6. Install and configure `auditd` service.
7. Install optional Mesh Commander scripts.
8. Setup Google observability agents (Monitoring and Logging) on physical hosts.
9. Remove provisioning GSA profile and key files.
10. Add and run cluster validation test script.

**Variables:**
- **Defined in `vars/main.yml`:** `kube_ps1_version`, `abm_install_user`, `external_secrets_files`.
- **Used from `all.yml`:** `abm_version`, `tools_base_path`, `primary_cluster_machine`, `install_observability`, `is_cloud_resource`, `remote_keys_folder`, `vpn_tunnel_name`, `google_region`, `google_project_id`, `gateway_ip`, `acm_config_files`, `kubeconfig_shared_location`, `machine_label`.

---

### ansible-pull
**Primary Goal:** Configures nodes to run Ansible playbooks locally via `ansible-pull` for drift management.

**Ordered Tasks:**
1. Setup Python3 and Pip.
2. Install Ansible via pip.
3. Create local working directories for playbooks and inventory.
4. Generate local inventory and variables files.
5. Create cron jobs for remote execution and drift management.
6. Setup log rotation for `ansible-pull` logs.

**Variables:**
- **Defined in `vars/main.yml`:** `ansible_pull_workdir`, `ansible_pull_workdir_permissions`, `ansible_pull_cmd_flags`, `ansible_pull_remote_execute_cron`, `ansible_pull_remote_execution_log`, `ansible_pull_drift_cron`, `ansible_pull_drift_log`, `ansible_pull_inventory_folder`.
- **Used from `all.yml`:** `target_os`, `cluster_name`, `machine_label`, `node_ip`, `peer_node_ips`, `primary_cluster_machine`, `google_project_id`, `google_secret_project_id`, `ansible_pull_remote_execute_repo`, `ansible_pull_cluster_ops_repo`.

---

### abm-login-token
**Primary Goal:** Retrieves the Kubernetes service account token for console login.

**Ordered Tasks:**
1. Test for the presence of the `root-reconciler` deployment.
2. Retrieve and display the login token for the cluster reader.

**Variables:**
- **Used from `all.yml`:** `kubeconfig_shared_location`, `primary_cluster_machine`.

---

### coral-tpu-install
**Primary Goal:** Installs drivers and packages for Coral EdgeTPU hardware.

**Ordered Tasks:**
1. Check if Coral TPU hardware is present.
2. Setup Google Cloud apt repository for Coral.
3. Install `libedgetpu1-std` and `gasket-dkms`.
4. Reboot to load the new kernel module.

**Variables:**
- **Used from `all.yml`:** `install_coral_tpu`.

---

### nvidia-drivers-install
**Primary Goal:** Installs NVIDIA drivers and container runtime configuration for GPU support.

**Ordered Tasks:**
1. Import NVIDIA GPG key.
2. Add NVIDIA container toolkit repository.
3. Install `nvidia-container-toolkit`.
4. Configure `containerd` runtime for NVIDIA.
5. Restart `containerd` service.

**Variables:**
- **Defined in `vars/main.yml`:** `nvidia_gpg_key`, `nvidia_key_location`, `nvidia_source_list`.
- **Used from `all.yml`:** `install_nvidia_gpu`.

---

### abm-remove
**Primary Goal:** Uninstalls ABM software and cleans up local workspaces and storage resources.

**Ordered Tasks:**
1. Check for the existence of the ABM workspace folder.
2. Copy provisioning GSA to nodes for reset.
3. Perform ABM reset using `bmctl reset`.
4. Remove ABM workspace and bmctl-workspace folders.
5. Remove shared kubeconfig folder.
6. Reboot the machine to reset LVM and in-memory state.

**Variables:**
- **Defined in `vars/main.yml`:** `abm_workspace_folder`, `gcs_bucketname_regex`, `robin_lvm_group_name`.
- **Used from `all.yml`:** `abm_install_folder`, `provisioning_gsa_key`, `remote_keys_folder`, `cluster_name`, `kubeconfig_shared_location`, `kubeconfig_shared_root`, `robin_disk_paths`, `google_project_id`, `snapshot_gcs_bucket_base`.

---

### cleanup
**Primary Goal:** Cleans up local temporary files and sensitive keys after provisioning.

**Ordered Tasks:**
1. Verify SSH and GSA keys exist in GCP Secret Manager before removal.
2. Remove local SSH private key file.
3. Remove local provisioning GSA key file.
4. Remove local node GSA key file.

**Variables:**
- **Used from `all.yml`:** `ansible_ssh_private_key_file`, `ansible_ssh_priv_key_secret`, `google_secret_project_id`, `primary_cluster_machine`, `provisioning_gsa_key`, `provisioning_gsa_key_secret`, `node_gsa_key`, `node_gsa_key_secret`.

---

### gdce-provision
**Primary Goal:** Basic provisioning checks and kubeconfig retrieval for GDCE.

**Ordered Tasks:**
1. Retrieve kubeconfig using `gcloud container hub memberships get-credentials`.
2. Verify node access using `kubectl get nodes`.

**Variables:**
- **Used from `all.yml`:** `cluster_name`, `google_project_id`, `instance_run_state_folder`.

---

### pre-cache-binaries
**Primary Goal:** Deploys pre-downloaded binary artifacts to the node to reduce external bandwidth usage.

**Ordered Tasks:**
1. Create a temporary staging directory.
2. Fetch the artifact bundle from a local folder or GCS bucket.
3. Unpack the bundle directly to the root filesystem.
4. Cleanup temporary files.

**Variables:**
- **Defined in `vars/main.yml`:** `bundle_file_name`, `local_cache_folder`, `bucket_cache_url`.
- **Used from `all.yml`:** `acm_config_files`, `must_use_precache`.

---

### reset-logs
**Primary Goal:** Resets the Stackdriver logging components on the cluster.

**Ordered Tasks:**
1. Scale down the `stackdriver-operator`.
2. Delete the `stackdriver-log-forwarder` daemonset.
3. Remove buffered log files from the node.
4. Scale up the `stackdriver-operator`.

**Variables:**
- **Used from `all.yml`:** `kubeconfig_shared_location`.