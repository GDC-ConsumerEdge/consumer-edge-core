#! /bin/bash
#Run from inside of either CloudShell or a Bastion VM inside of the same GCP project as the GCP cnuc's
###

# Must currently run as an admin user with org permissions in order to make the changes throughout
# For now this means we will require that the user login via gcloud auth login
# This check will bail if a gserviceaccount is found in use
GSERVICEACCOUNT=$(gcloud auth list --format=json | grep gserviceaccount)
if [[ ! -z "${GSERVICEACCOUNT}" ]]; then
	echo "Please login as an admin user account using the following command -- 'gcloud auth login --no-browser'"
	echo "This will require you to have run 'gcloud auth login' on your local machines terminal (CloudShell will not work)"
	exit 1
fi
echo "Beginning Installation!"

sudo apt update
sudo apt -y install screen
echo "termcapinfo xterm* ti@:te@" > .screenrc

sudo apt -y install git
sudo apt -y remove docker docker-engine docker.io containerd runc
sudo apt -y install ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --yes --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
	  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
	    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt -y install docker-ce docker-ce-cli containerd.io
sudo apt -y install jq -y
sudo apt -y install unzip direnv
sudo usermod -aG docker $(whoami)
sudo chmod 666 /var/run/docker.sock
echo "Finished Docker setup..."
#mv algsa-key.json creds-gcp.json
##Instal GS
#yes Y | gcloud secrets create gcs-auth-secret
#gcloud secrets versions add gcs-auth-secret --data-file="creds-gcp.json"

echo "Adding direnv hook to bask & allowing direnv for the current direction"
echo 'eval "$(direnv hook bash)"' >> ~/.bashrc
direnv allow
source ~/.bashrc

##Begin setting up to run  ./install
if [[ ! -f "./build-artifacts/consumer-edge-machine" ]]; then
	echo "Creating SSH keys consumer-edge-machine"
	ssh-keygen -o -a 100 -t ed25519 -f ./build-artifacts/consumer-edge-machine -N ''
else
	echo "Found existing ./build-artifacts/consumer-edge-machine, skipping creation"
fi

export QL_PROJECT_ID=$(gcloud projects list --format=json | jq -r ".[0] .projectId")
export QL_ROOT_REPO="https://gitlab.com/gcp-solutions-public/retail-edge/root-repo-edge-workshop"

echo "##Running gcloud config set project $QL_PROJECT_ID"
gcloud config set project $QL_PROJECT_ID
echo "##Running yes Y | gcloud auth configure-docker"
yes Y | gcloud auth configure-docker

# make "default" network check to see if it doesnt exist
# ensure non-conflicting CIDR - ... set to automatic

NETWORK="default"
HAS_NETWORK=$(gcloud compute networks list --filter="name~${NETWORK}" --format="value(name)")

if [[ -z "${HAS_NETWORK}" ]]; then
	gcloud compute networks create "${NETWORK}" \
		--subnet-mode=auto \
		--bgp-routing-mode=regional
else
	echo "Skipping creating network ${NETWORK}, already exists"
fi

# Create default FW rules - assume 0.0.0.0/0 for all entries below
declare -a global_firewall_rules=(
	"gdc-allow-kubectl|tcp:6443"
	"gdc-allow-iap-traffic|tcp:22,tcp:80,tcp:443,tcp:3389"
	"gdc-allow-icmp|icmp"
)
# Create default FW fules - assume 10.0.0.0/0 for all entries below
declare -a internal_firewall_rules=(
	"gdc-allow-internal|tcp:0-65535,udp:0-65535,icmp"
)

# Loop to implement global FW rules
for fw_rule in "${global_firewall_rules[@]}"
do
	# IFS='|' read -r -a array <<< "name1|name2|name3"; echo ${array[0]} ${array[1]} ${array[2]}
	# Above outpues "name1 name2 name3"
	IFS="|" read -r -a array <<< "$fw_rule"
	echo "gcloud compute firewall-rules create ${array[0]} --allow ${array[1]}"
	gcloud compute firewall-rules create ${array[0]} --allow ${array[1]}
done

# Loop to implement 10.0.0.0/8 FW rules for internal access
for fw_rule in "${internal_firewall_rules[@]}"
do
	# IFS='|' read -r -a array <<< "name1|name2|name3"; echo ${array[0]} ${array[1]} ${array[2]}
	# Above outpues "name1 name2 name3"
	IFS="|" read -r -a array <<< "$fw_rule"
	echo "gcloud compute firewall-rules create ${array[0]} --allow ${array[1]} --source-ranges='10.0.0.0/8'"
	gcloud compute firewall-rules create ${array[0]} --allow ${array[1]} --source-ranges="10.0.0.0/8"
done


envsubst < templates/envrc-template.sh > .envrc
sed -i "s/PROJECT_ID=.*/PROJECT_ID=\"$QL_PROJECT_ID\"/g" .envrc
#sed -i "s,ROOT_REPO_URL=.*,ROOT_REPO_URL=\"$QL_ROOT_REPO\",g" .envrc
source .envrc

yes Y | ./scripts/create-primary-gsa.sh
if [[ ! -f "./build-artifacts/consumer-edge-machine.encrypted" ]]; then
 	echo "Creating consumer-edge-machine.encrypted file"
# 	yes Y | gcloud kms keyrings create gdc-ce-keyring --location=global
 	gcloud kms encrypt --key gdc-ssh-key --keyring gdc-ce-keyring --location global \
 		--plaintext-file build-artifacts/consumer-edge-machine \
 		--ciphertext-file build-artifacts/consumer-edge-machine.encrypted
else
 	echo "Found existing ./build-artifacts/consumer-edge-machine.encrypted, skipping creation"
fi
# Create the 3 cnuc VMs
source .envrc
./scripts/cloud/create-cloud-gce-baseline.sh -c 3

export CONTAINER_URL=$(gcloud container images list --repository=gcr.io/$PROJECT_ID --format="value(name)" --filter="name~consumer-edge-install")
if [[ -z "$CONTAINER_URL" ]]; then
	cd docker-build
	echo "Starting Cloud Build Install Container!"
	gcloud builds submit --config cloudbuild.yaml .
	cd ..
else
	echo "Found exsiting container: $CONTAINER_URL"
fi
source .envrc
envsubst < templates/inventory-cloud-example.yaml > inventory/gcp.yml
##Ready to run ./install.sh
echo "Ready to run ./install.sh"
