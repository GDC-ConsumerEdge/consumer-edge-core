#! /bin/bash
# Use gcloud to pull active project Id
export PROJECT_ID=$(gcloud projects list --format=json | jq -r ".[0] .projectId")

# Disable Policies without Constraints
gcloud beta resource-manager org-policies disable-enforce compute.requireShieldedVm --project=$PROJECT_ID
gcloud beta resource-manager org-policies disable-enforce compute.requireOsLogin --project=$PROJECT_ID
gcloud beta resource-manager org-policies disable-enforce iam.disableServiceAccountKeyCreation --project=$PROJECT_ID
gcloud beta resource-manager org-policies disable-enforce iam.disableServiceAccountKeyUpload --project=$PROJECT_ID
gcloud beta resource-manager org-policies disable-enforce iam.disableServiceAccountCreation --project=$PROJECT_ID
gcloud beta resource-manager org-policies disable-enforce iam.automaticIamGrantsForDefaultServiceAccounts --project=$PROJECT_ID
gcloud beta resource-manager org-policies disable-enforce compute.disableNestedVirtualization --project=$PROJECT_ID

# now loop and fix policies with  constraints in Argolis 
# Inner Loop - Loop Through Policies with Constraints
declare -a policies=("constraints/compute.trustedImageProjects"
 "constraints/compute.vmExternalIpAccess"
 "constraints/compute.restrictSharedVpcSubnetworks"
 "constraints/compute.restrictSharedVpcHostProjects" 
 "constraints/compute.restrictVpcPeering"
 "constraints/compute.vmCanIpForward")

for policy in "${policies[@]}"
do
cat <<EOF > new_policy.yaml
constraint: $policy
listPolicy:
 allValues: ALLOW
EOF
    gcloud resource-manager org-policies set-policy new_policy.yaml --project=$PROJECT_ID
done
##Ready to run ./setup.sh
echo "Ready to run ./setup.sh"
