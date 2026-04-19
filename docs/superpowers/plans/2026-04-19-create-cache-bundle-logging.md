# Create Cache Bundle Logging Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve `scripts/create-cache-bundle.sh` by adding structured logging, pre-flight checks, and robust error handling.

**Architecture:** We will add standard bash logging functions (INFO, SUCCESS, ERROR, WARN), setup an `EXIT` trap to ensure the staging directory is always cleaned up, setup an `ERR` trap to log line numbers on failure, and add pre-flight checks for required CLI tools. We'll also wrap the download steps with informative logs.

**Tech Stack:** Bash

---

### Task 1: Update `scripts/create-cache-bundle.sh` with Logging and Checks

We will replace the contents of the script to incorporate all the new features from the design.

**Files:**
- Modify: `scripts/create-cache-bundle.sh`

- [ ] **Step 1: Replace the file content**

Replace the contents of `scripts/create-cache-bundle.sh` with the following:

```bash
#!/bin/bash
# Copyright 2023 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -eo pipefail

log_info() { echo -e "\033[1;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[1;32m[SUCCESS]\033[0m $1"; }
log_warn() { echo -e "\033[1;33m[WARN]\033[0m $1"; }
log_error() { echo -e "\033[1;31m[ERROR]\033[0m $1"; }

handle_error() {
  local line=$1
  log_error "Command failed at line $line"
}
trap 'handle_error ${LINENO}' ERR

cleanup() {
  if [[ -n "${staging_dir:-}" && -d "${staging_dir}" ]]; then
    log_info "Cleaning up ${staging_dir}..."
    rm -rf "${staging_dir}"
  fi
}
trap cleanup EXIT

# Pre-flight checks
log_info "Running pre-flight checks..."
for cmd in gcloud wget tar mktemp; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log_error "Required command '$cmd' is not installed."
    exit 1
  fi
done
log_success "Pre-flight checks passed."

staging_dir=$(mktemp -d -t cache-binaries-XXXXXXXXXX)
log_info "Using '${staging_dir}' as staging directory to construct the filesystem hierarchy."

# Create root directory structure
mkdir -p "${staging_dir}/usr/local/bin"
mkdir -p "${staging_dir}/usr/bin"
mkdir -p "${staging_dir}/var/acm-configs"
mkdir -p "${staging_dir}/var/kube-ps1/kube-ps1-0.7.0"
mkdir -p "${staging_dir}/var/abm-install/tools"
mkdir -p "${staging_dir}/tmp"

# ACM Operator
export acm_version="1.16.0"
log_info "Downloading ACM Operator v${acm_version}..."
gcloud storage cp gs://config-management-release/released/${acm_version}/config-management-operator.yaml "${staging_dir}/var/acm-configs/" >/dev/null 2>&1
log_success "Staged ACM Operator."

export k9s_version="v0.26.3"
log_info "Downloading k9s v${k9s_version}..."
wget -q https://github.com/derailed/k9s/releases/download/${k9s_version}/k9s_Linux_x86_64.tar.gz -O /tmp/k9s.tar.gz
tar xf /tmp/k9s.tar.gz -C /tmp k9s
chmod +x /tmp/k9s
mv /tmp/k9s "${staging_dir}/usr/local/bin/"
log_success "Staged k9s."

export kubectx_version="0.9.4"
log_info "Downloading kubectx & kubens v${kubectx_version}..."
wget -q https://github.com/ahmetb/kubectx/releases/download/v${kubectx_version}/kubectx_v${kubectx_version}_linux_x86_64.tar.gz -O /tmp/kubectx.tar.gz
tar xf /tmp/kubectx.tar.gz -C /tmp kubectx
chmod +x /tmp/kubectx
mv /tmp/kubectx "${staging_dir}/usr/local/bin/"

wget -q https://github.com/ahmetb/kubectx/releases/download/v${kubectx_version}/kubens_v${kubectx_version}_linux_x86_64.tar.gz -O /tmp/kubens.tar.gz
tar xf /tmp/kubens.tar.gz -C /tmp kubens
chmod +x /tmp/kubens
mv /tmp/kubens "${staging_dir}/usr/local/bin/"
log_success "Staged kubectx and kubens."

export bmctl_version="1.34.300-gke.59"
log_info "Downloading bmctl v${bmctl_version}..."
gcloud storage cp gs://anthos-baremetal-release/bmctl/${bmctl_version}/linux-amd64/bmctl "${staging_dir}/usr/local/bin/" >/dev/null 2>&1
chmod +x "${staging_dir}/usr/local/bin/bmctl"
log_success "Staged bmctl."

export VERSION="v0.49.1"
log_info "Downloading kubevirt virtctl v${VERSION}..."
wget -q https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/virtctl-${VERSION}-linux-amd64 -O "${staging_dir}/usr/bin/kubectl-virt"
chmod +x "${staging_dir}/usr/bin/kubectl-virt"
log_success "Staged virtctl."

export kube_ps1_version="0.7.0"
log_info "Downloading kube-ps1 v${kube_ps1_version}..."
wget -q https://github.com/jonmosco/kube-ps1/archive/refs/tags/v${kube_ps1_version}.tar.gz -O /tmp/ps1.tar.gz
tar xf /tmp/ps1.tar.gz -C /tmp --strip-components=1 kube-ps1-${kube_ps1_version}/kube-ps1.sh
mv /tmp/kube-ps1.sh "${staging_dir}/var/kube-ps1/kube-ps1-0.7.0/"
log_success "Staged kube-ps1."

export kubestr_version="v0.4.49"
log_info "Downloading kubestr ${kubestr_version}..."
wget -q https://github.com/kastenhq/kubestr/releases/download/${kubestr_version}/kubestr_${kubestr_version}_Linux_amd64.tar.gz -O /tmp/kubestr.tar.gz
tar xf /tmp/kubestr.tar.gz -C /tmp kubestr
chmod +x /tmp/kubestr
mv /tmp/kubestr "${staging_dir}/usr/local/bin/"
log_success "Staged kubestr."

export ncgctl_version="v1.12.0"
log_info "Downloading ncgctl v${ncgctl_version}..."
gcloud storage cp gs://ncg-release/anthos-baremetal/ncgctl-${ncgctl_version}-linux-amd64.tar.gz /tmp/ >/dev/null 2>&1
tar xf /tmp/ncgctl-${ncgctl_version}-linux-amd64.tar.gz -C /tmp
mv "/tmp/ncgctl-${ncgctl_version}" "${staging_dir}/var/abm-install/tools/"
log_success "Staged ncgctl."

log_info "Downloading helper scripts (get-docker, agent repos)..."
wget -q https://get.docker.com -O "${staging_dir}/tmp/get-docker.sh"
chmod +x "${staging_dir}/tmp/get-docker.sh"

wget -q https://dl.google.com/cloudagents/add-monitoring-agent-repo.sh -O "${staging_dir}/tmp/add-monitoring-agent-repo.sh"
chmod +x "${staging_dir}/tmp/add-monitoring-agent-repo.sh"

wget -q https://dl.google.com/cloudagents/add-logging-agent-repo.sh -O "${staging_dir}/tmp/add-logging-agent-repo.sh"
chmod +x "${staging_dir}/tmp/add-logging-agent-repo.sh"
log_success "Staged helper scripts."

export gcloud_version="558.0.0"
log_info "Downloading Google Cloud SDK v${gcloud_version}..."
wget -q https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${gcloud_version}-linux-x86_64.tar.gz -O /tmp/gcloud.tar.gz
tar xf /tmp/gcloud.tar.gz -C /tmp
mv /tmp/google-cloud-sdk "${staging_dir}/var/abm-install/tools/"
log_success "Staged Google Cloud SDK."

log_info "Constructed File System Hierarchy:"
find "${staging_dir}" -type f

export WORKDIR="$(pwd)"
log_info "Creating tarball..."
tar -czf "${WORKDIR}/pre-cache-bundle.tar.gz" -C "${staging_dir}" .

log_success "Pre-cache bundle tarball created at ${WORKDIR}/pre-cache-bundle.tar.gz"
```

- [ ] **Step 2: Verify Syntax**

Run a syntax check on the script.

```bash
bash -n scripts/create-cache-bundle.sh
```

Expected output: No output (which means syntax is valid).

- [ ] **Step 3: Commit**

```bash
git add scripts/create-cache-bundle.sh
git commit -m "feat: enhance logging and error handling in create-cache-bundle.sh"
```
