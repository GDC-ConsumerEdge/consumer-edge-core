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
  local command="$2"
  log_error "Command '${command}' failed at line $line"
}
trap 'handle_error ${LINENO} "$BASH_COMMAND"' ERR

cleanup() {
  if [[ -n "${staging_dir:-}" && -d "${staging_dir}" ]]; then
    log_info "Cleaning up ${staging_dir}..."
    rm -rf "${staging_dir}"
  fi
}
trap cleanup EXIT

# Pre-flight checks
log_info "Running pre-flight checks..."
for cmd in gcloud wget tar mktemp jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log_error "Required command '$cmd' is not installed."
    exit 1
  fi
done
log_success "Pre-flight checks passed."

# Define all versions and links
export acm_version="1.16.0"
acm_link="gs://config-management-release/released/${acm_version}/config-management-operator.yaml"

export k9s_version="v0.26.3"
k9s_link="https://github.com/derailed/k9s/releases/download/${k9s_version}/k9s_Linux_x86_64.tar.gz"

export kubectx_version="0.9.4"
kubectx_link="https://github.com/ahmetb/kubectx/releases/download/v${kubectx_version}/kubectx_v${kubectx_version}_linux_x86_64.tar.gz"
kubens_link="https://github.com/ahmetb/kubectx/releases/download/v${kubectx_version}/kubens_v${kubectx_version}_linux_x86_64.tar.gz"

export bmctl_version="1.34.300-gke.59"
bmctl_link="gs://anthos-baremetal-release/bmctl/${bmctl_version}/linux-amd64/bmctl"

export virtctl_version="v0.49.1"
virtctl_link="https://github.com/kubevirt/kubevirt/releases/download/${virtctl_version}/virtctl-${virtctl_version}-linux-amd64"

export kube_ps1_version="0.7.0"
kube_ps1_link="https://github.com/jonmosco/kube-ps1/archive/refs/tags/v${kube_ps1_version}.tar.gz"

export kubestr_version="0.4.49"
kubestr_link="https://github.com/kastenhq/kubestr/releases/download/v${kubestr_version}/kubestr_${kubestr_version}_Linux_amd64.tar.gz"

export ncgctl_version="v1.12.0"
ncgctl_link="gs://ncg-release/anthos-baremetal/ncgctl-${ncgctl_version}-linux-amd64.tar.gz"

docker_link="https://get.docker.com"
mon_agent_link="https://dl.google.com/cloudagents/add-monitoring-agent-repo.sh"
log_agent_link="https://dl.google.com/cloudagents/add-logging-agent-repo.sh"

export gcloud_version="558.0.0"
gcloud_link="https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${gcloud_version}-linux-x86_64.tar.gz"

# Generate Manifest Markdown
MANIFEST_MD=$(cat <<EOFMARKDOWN
# Cache Bundle Manifest

| Binary Name | Version | Destination | Download Link |
|---|---|---|---|
| ACM Operator | ${acm_version} | \`/var/acm-configs/\` | ${acm_link} |
| k9s | ${k9s_version} | \`/usr/local/bin/\` | ${k9s_link} |
| kubectx | ${kubectx_version} | \`/usr/local/bin/\` | ${kubectx_link} |
| kubens | ${kubectx_version} | \`/usr/local/bin/\` | ${kubens_link} |
| bmctl | ${bmctl_version} | \`/usr/local/bin/\` | ${bmctl_link} |
| virtctl | ${virtctl_version} | \`/usr/bin/kubectl-virt\` | ${virtctl_link} |
| kube-ps1 | ${kube_ps1_version} | \`/var/kube-ps1/kube-ps1-0.7.0/\` | ${kube_ps1_link} |
| kubestr | ${kubestr_version} | \`/usr/local/bin/\` | ${kubestr_link} |
| ncgctl | ${ncgctl_version} | \`/var/abm-install/tools/\` | ${ncgctl_link} |
| get-docker.sh | N/A | \`/tmp/\` | ${docker_link} |
| add-monitoring-agent-repo.sh | N/A | \`/tmp/\` | ${mon_agent_link} |
| add-logging-agent-repo.sh | N/A | \`/tmp/\` | ${log_agent_link} |
| Google Cloud SDK | ${gcloud_version} | \`/var/abm-install/tools/google-cloud-sdk\` | ${gcloud_link} |
EOFMARKDOWN
)

log_info "Bundle Manifest:\n${MANIFEST_MD}"

staging_dir=$(mktemp -d -t cache-binaries-XXXXXXXXXX)
log_info "Using '${staging_dir}' as staging directory to construct the filesystem hierarchy."

# Create root directory structure
mkdir -p "${staging_dir}/usr/local/bin"
mkdir -p "${staging_dir}/usr/bin"
mkdir -p "${staging_dir}/var/acm-configs"
mkdir -p "${staging_dir}/var/kube-ps1/kube-ps1-0.7.0"
mkdir -p "${staging_dir}/var/abm-install/tools"
mkdir -p "${staging_dir}/tmp"

# Write manifest to bundle
echo "${MANIFEST_MD}" > "${staging_dir}/manifest.md"

# ACM Operator
log_info "Downloading ACM Operator v${acm_version}..."
gcloud storage cp "${acm_link}" "${staging_dir}/var/acm-configs/" >/dev/null 2>&1
log_success "Staged ACM Operator."

log_info "Downloading k9s v${k9s_version}..."
wget -q "${k9s_link}" -O /tmp/k9s.tar.gz
tar xf /tmp/k9s.tar.gz -C /tmp k9s
chmod +x /tmp/k9s
mv /tmp/k9s "${staging_dir}/usr/local/bin/"
log_success "Staged k9s."

log_info "Downloading kubectx & kubens v${kubectx_version}..."
wget -q "${kubectx_link}" -O /tmp/kubectx.tar.gz
tar xf /tmp/kubectx.tar.gz -C /tmp kubectx
chmod +x /tmp/kubectx
mv /tmp/kubectx "${staging_dir}/usr/local/bin/"

wget -q "${kubens_link}" -O /tmp/kubens.tar.gz
tar xf /tmp/kubens.tar.gz -C /tmp kubens
chmod +x /tmp/kubens
mv /tmp/kubens "${staging_dir}/usr/local/bin/"
log_success "Staged kubectx and kubens."

log_info "Downloading bmctl v${bmctl_version}..."
gcloud storage cp "${bmctl_link}" "${staging_dir}/usr/local/bin/" >/dev/null 2>&1
chmod +x "${staging_dir}/usr/local/bin/bmctl"
log_success "Staged bmctl."

log_info "Downloading kubevirt virtctl v${virtctl_version}..."
wget -q "${virtctl_link}" -O "${staging_dir}/usr/bin/kubectl-virt"
chmod +x "${staging_dir}/usr/bin/kubectl-virt"
log_success "Staged virtctl."

log_info "Downloading kube-ps1 v${kube_ps1_version}..."
wget -q "${kube_ps1_link}" -O /tmp/ps1.tar.gz
tar xf /tmp/ps1.tar.gz -C /tmp --strip-components=1 kube-ps1-${kube_ps1_version}/kube-ps1.sh
mv /tmp/kube-ps1.sh "${staging_dir}/var/kube-ps1/kube-ps1-0.7.0/"
log_success "Staged kube-ps1."

log_info "Downloading kubestr ${kubestr_version}..."
wget -q "${kubestr_link}" -O /tmp/kubestr.tar.gz
tar xf /tmp/kubestr.tar.gz -C /tmp kubestr
chmod +x /tmp/kubestr
mv /tmp/kubestr "${staging_dir}/usr/local/bin/"
log_success "Staged kubestr."

log_info "Downloading ncgctl v${ncgctl_version}..."
gcloud storage cp "${ncgctl_link}" /tmp/ >/dev/null 2>&1
tar xf /tmp/ncgctl-${ncgctl_version}-linux-amd64.tar.gz -C /tmp
mv "/tmp/ncgctl-${ncgctl_version}" "${staging_dir}/var/abm-install/tools/"
log_success "Staged ncgctl."

log_info "Downloading helper scripts (get-docker, agent repos)..."
wget -q "${docker_link}" -O "${staging_dir}/tmp/get-docker.sh"
chmod +x "${staging_dir}/tmp/get-docker.sh"

wget -q "${mon_agent_link}" -O "${staging_dir}/tmp/add-monitoring-agent-repo.sh"
chmod +x "${staging_dir}/tmp/add-monitoring-agent-repo.sh"

wget -q "${log_agent_link}" -O "${staging_dir}/tmp/add-logging-agent-repo.sh"
chmod +x "${staging_dir}/tmp/add-logging-agent-repo.sh"
log_success "Staged helper scripts."

log_info "Downloading Google Cloud SDK v${gcloud_version}..."
wget -q "${gcloud_link}" -O /tmp/gcloud.tar.gz
tar xf /tmp/gcloud.tar.gz -C /tmp
mv /tmp/google-cloud-sdk "${staging_dir}/var/abm-install/tools/"
log_success "Staged Google Cloud SDK."

log_info "Constructed File System Hierarchy:"
find "${staging_dir}" -type f

export WORKDIR="$(pwd)"
log_info "Creating tarball..."
tar -czf "${WORKDIR}/pre-cache-bundle.tar.gz" -C "${staging_dir}" .

log_success "Pre-cache bundle tarball created at ${WORKDIR}/pre-cache-bundle.tar.gz"
