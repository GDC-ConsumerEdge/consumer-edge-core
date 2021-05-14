#!/bin/bash

set -x
set -e

echo "Starting GCE Init script"

## THIS IS RUN AS A STARTUP SCRIPT FOR GCE INSTANCES
## The purpose of this script is to establish a baseline
## that is semantically the same as the NUCs for ABM Consumer Edge


# 0. Very baseline libraries/apps used for this portion only (please use the Ansible roles to baseline the full image)
apt-get -qq update > /dev/null
apt-get -qq install -y jq > /dev/null

# 1. Establish a user (same user for all GCEs)
useradd -m -s /bin/bash -g users ${ANSIBLE_USER}
echo "${ANSIBLE_USER}  ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/${ANSIBLE_USER}

# 2. Copy/place/setup a authorized_keys from a GCP Secret under that user and under root
gcloud secrets versions access latest --secret=${PROVISION_KEY_PUB_KEY} > /tmp/install-pub-key.pub

# 3. Setup a common password for root (or setup user to be sudoer)
mkdir -p /home/${ANSIBLE_USER}/.ssh
cat /tmp/install-pub-key.pub >> /home/${ANSIBLE_USER}/.ssh/authorized_keys

# 4. Setup VXLAN configuration
ip link add vxlan0 type vxlan id 42 dev ens4 dstport 0
current_ip=$(ip --json a show dev ens4 | jq '.[0].addr_info[0].local' -r)
# not really needed, but handy just in case
echo $current_ip

# IP=2
# 10.200.0.2/24 TODO: Save for later. This could be used to link 2 GCE instances via vxlan together, then one would be 2 and the other would be 3...
### this would be the other IPs in the cluster group
# for ip in ${IPs[@]}; do
#     if [ "\$ip" != "\$current_ip" ]; then
#         bridge fdb append to 00:00:00:00:00:00 dst \$ip dev vxlan0
#     fi
# done

ip addr add 10.200.0.2/24 dev vxlan0
ip link set up dev vxlan0
