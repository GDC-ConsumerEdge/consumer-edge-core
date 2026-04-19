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


tmp_dir=$(mktemp -d -t cache-binaries-XXXXXXXXXX)

echo "Using '${tmp_dir}' to put all binaries in"


mkdir -p "${tmp_dir}/bin"

# ACM Operator
export acm_version="1.13.0"
gcloud storage cp gs://config-management-release/released/${acm_version}/config-management-operator.yaml .
mv config-management-operator.yaml "${tmp_dir}/bin"

export k9s_version="v0.26.3"
wget https://github.com/derailed/k9s/releases/download/${k9s_version}/k9s_Linux_x86_64.tar.gz -O k9s.tar.gz
tar xvf k9s.tar.gz
chmod +x k9s
mv k9s "${tmp_dir}/bin"

export kubectx_version="0.9.4"
wget https://github.com/ahmetb/kubectx/releases/download/v${kubectx_version}/kubectx_v${kubectx_version}_linux_x86_64.tar.gz -O kubectx.tar.gz
tar xvf kubectx.tar.gz
chmod +x kubectx
mv kubectx "${tmp_dir}/bin"

export kubectx_version="0.9.4"
wget https://github.com/ahmetb/kubectx/releases/download/v${kubectx_version}/kubens_v${kubectx_version}_linux_x86_64.tar.gz -O kubens.tar.gz
tar xvf kubens.tar.gz
chmod +x kubens
mv kubens "${tmp_dir}/bin"

export bmctl_version="1.13.0"
gcloud storage cp gs://anthos-baremetal-release/bmctl/${bmctl_version}/linux-amd64/bmctl .
chmod +x bmctl
mv bmctl "${tmp_dir}/bin"

export VERSION="v0.49.1"
wget https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/virtctl-${VERSION}-linux-amd64 -O virtctl
chmod +x virtctl
mv virtctl "${tmp_dir}/bin"

export kube_ps1_version="0.7.0"
wget https://github.com/jonmosco/kube-ps1/archive/refs/tags/v${kube_ps1_version}.tar.gz -O ps1.tar.gz
tar xvf ps1.tar.gz --strip-components=1
mv kube-ps1.sh "${tmp_dir}/bin"

export kubestr_version="v0.4.49"
wget https://github.com/kastenhq/kubestr/releases/download/${kubestr_version}/kubestr_${kubestr_version}_Linux_amd64.tar.gz -O kubestr.tar.gz
tar xvf kubestr.tar.gz kubestr
chmod +x kubestr
mv kubestr "${tmp_dir}/bin"

export ncgctl_version="v1.12.0"
gcloud storage cp gs://ncg-release/anthos-baremetal/ncgctl-${ncgctl_version}-linux-amd64.tar.gz .
tar xvf ncgctl-${ncgctl_version}-linux-amd64.tar.gz
mv ncgctl-${ncgctl_version} "${tmp_dir}/bin/"

wget https://get.docker.com -O get-docker.sh
mv get-docker.sh "${tmp_dir}/bin"

wget https://dl.google.com/cloudagents/add-monitoring-agent-repo.sh -O add-monitoring-agent-repo.sh
mv add-monitoring-agent-repo.sh "${tmp_dir}/bin"

wget https://dl.google.com/cloudagents/add-logging-agent-repo.sh -O add-logging-agent-repo.sh
mv add-logging-agent-repo.sh "${tmp_dir}/bin"

export gcloud_version="558.0.0"
wget https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${gcloud_version}-linux-x86_64.tar.gz -O gcloud.tar.gz
tar xvf gcloud.tar.gz
mv google-cloud-sdk "${tmp_dir}/bin/"

# Create "config" file

cat << EOF > ${tmp_dir}/config.csv
bmctl,/usr/local/bin
virtctl,/usr/bin/kubectl-virt
kubens,/usr/local/bin/kubens
kubectx,/usr/local/bin/kubectx
k9s,/usr/local/bin/k9s
kubestr,/usr/local/bin/kubestr
config-management-operator.yaml,/var/acm-configs/config-management-operator.yaml
kube-ps1.sh,/var/kube-ps1/kube-ps1-0.7.0/kube-ps1.sh
ncgctl-${ncgctl_version},/var/abm-install/tools
get-docker.sh,/tmp/get-docker.sh
add-monitoring-agent-repo.sh,/tmp/add-monitoring-agent-repo.sh
add-logging-agent-repo.sh,/tmp/add-logging-agent-repo.sh
google-cloud-sdk,/var/abm-install/tools/google-cloud-sdk
EOF

# List out binaries
ls -al ${tmp_dir}/bin

export WORKDIR="$(pwd)"
pushd ${tmp_dir}; zip -r ${WORKDIR}/bundle.zip .; popd

echo "${tmp_dir}"
