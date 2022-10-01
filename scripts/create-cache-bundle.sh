#!/bin/bash

tmp_dir=$(mktemp -d -t cache-binaries-XXXXXXXXXX)

echo "Using '${tmp_dir}' to put all binaries in"


mkdir -p "${tmp_dir}/bin"

# ACM Operator
export acm_version="1.13.0"
gsutil cp gs://config-management-release/released/${acm_version}/config-management-operator.yaml .
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
gsutil cp gs://anthos-baremetal-release/bmctl/${bmctl_version}/linux-amd64/bmctl .
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

# Create "config" file

cat << EOF > ${tmp_dir}/config.csv
bmctl,/usr/local/bin
virtctl,/usr/bin/kubectl-virt
kubens,/usr/local/bin/kubens
kubectx,/usr/local/bin/kubectx
k9s,/usr/local/bin/k9s
config-management-operator.yaml,/var/acm-configs/config-management-operator.yaml
kube-ps1.sh,/var/kube-ps1/kube-ps1-0.7.0/kube-ps1.sh
EOF

# List out binaries
ls -al ${tmp_dir}/bin

export WORKDIR="$(pwd)"
pushd ${tmp_dir}; zip -r ${WORKDIR}/bundle.zip .; popd

echo "${tmp_dir}"
