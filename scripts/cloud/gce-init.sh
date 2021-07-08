#!/bin/bash

set -x
set -e

echo "Starting GCE Init script"

## THIS IS RUN AS A STARTUP SCRIPT FOR GCE INSTANCES
## The purpose of this script is to establish a baseline
## that is semantically the same as the NUCs for ABM Consumer Edge

if [[ -f /etc/startup_was_launched ]]; then exit 0; fi
# touch a file to indicate init script has been launched
touch /etc/startup_was_launched

# Disable warning about dpkg not being available for interaction
export DEBIAN_FRONTEND=noninteractive

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
chown -R ${ANSIBLE_USER}.users /home/${ANSIBLE_USER}/.ssh

# 4. Setup VXLAN configuration
VXLAN_ID=$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/vxlanid -H "Metadata-Flavor: Google")
INSTANCE_ID=$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/instance -H "Metadata-Flavor: Google")
CLUSTER_ID=$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/cluster_id -H "Metadata-Flavor: Google")

VXLANIP="10.200.0.${CLUSTER_ID}"
MACHINE_NAME="cnuc-${INSTANCE_ID}"

### Setup the service to restart vxlan when rebooting

cat > ${SETUP_VXLAN_SCRIPT} <<EOF
#!/bin/bash

ip link add vxlan0 type vxlan id ${VXLAN_ID} dev ens4 dstport 0
ip addr add ${VXLANIP}/24 dev vxlan0

# Private IPs for all cnuc's on internal GCP network
IPs=( \$(gcloud compute instances list --filter="labels.vxlanid=${VXLAN_ID} AND name!=${MACHINE_NAME}" --format="value(networkInterfaces[0].networkIP)") )

# Loop over all IPs in group and bridge to VXLAN
for ip in \${IPs[@]}; do
    bridge fdb append to 00:00:00:00:00:00 dst \$ip dev vxlan0
done

# Enable VXLAN
ip link set up dev vxlan0

EOF

cat > ${SYSTEM_SERVICE_VXLAN} <<EOF
[Unit]

After=network.service

[Service]

ExecStart=${SETUP_VXLAN_SCRIPT}

[Install]

WantedBy=default.target
EOF

chmod 644 ${SYSTEM_SERVICE_VXLAN}
chmod 744 ${SETUP_VXLAN_SCRIPT}

# Setup vxlan service
systemctl enable ${SYSTEM_SERVICE_NAME}
# Start the vxlan service
systemctl start ${SYSTEM_SERVICE_NAME}

# setup SSH config to skip key checking
cat >> ~/.ssh/config <<EOF

# allow SSH without checking fingerprint for the 10.200.0.0/24 addresses
Host 10.200.0.*
    StrictHostKeyChecking no

EOF

# re-use the same SSH config for the ansible user
cp ~/.ssh/config /home/${ANSIBLE_USER}/.ssh/config
chown ${ANSIBLE_USER} /home/${ANSIBLE_USER}/.ssh/config # note, just assigning owner since group is 0 anyway
chmod 400 /home/${ANSIBLE_USER}/.ssh/config

# Set ownership and permissions
chmod 400 ~/.ssh/config

# Verify VXLAN IP works
ping -c 3 ${VXLANIP}
if [[ $? -gt 0 ]]; then
    echo "Cannot ping the vxlan IP address"
    exit 1
fi
