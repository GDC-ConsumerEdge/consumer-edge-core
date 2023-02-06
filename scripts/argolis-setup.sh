#!/bin/bash

if [[ -z "${PROJECT_ID}" ]]; then
    echo "PROJECT_ID is required to be set. Please set this"
fi

#ORG_ID="$(gcloud projects get-ancestors "${PROJECT_ID}" --format=json | jq -r -c '.[] | select( .type == "organization" ).id')" # organization ID of the current user's identity in Argolis (so Argolis's Org ID)

gcloud beta resource-manager org-policies disable-enforce compute.requireShieldedVm --project=${PROJECT_ID} --no-user-output-enabled
gcloud beta resource-manager org-policies disable-enforce compute.requireOsLogin --project=${PROJECT_ID} --no-user-output-enabled
gcloud beta resource-manager org-policies disable-enforce iam.disableServiceAccountKeyCreation --project=${PROJECT_ID} --no-user-output-enabled
gcloud beta resource-manager org-policies disable-enforce iam.disableServiceAccountCreation --project=${PROJECT_ID} --no-user-output-enabled

gcloud resource-manager org-policies set-policy /dev/stdin \
  --project="${PROJECT_ID}" <<EOF
constraint: constraints/iam.allowedPolicyMemberDomains
restoreDefault: {}
EOF

# now loop and fix policies with  constraints in Argolis
declare -a policies=("constraints/compute.trustedImageProjects"
 "constraints/compute.vmExternalIpAccess"
 "constraints/compute.restrictSharedVpcSubnetworks"
 "constraints/compute.restrictSharedVpcHostProjects"
 "constraints/compute.restrictVpcPeering"
 "constraints/compute.vmCanIpForward")

for policy in "${policies[@]}"
do
tmpfile=$(mktemp /tmp/new-policy.XXXXXX.yaml)
cat <<EOF > $tmpfile
constraint: $policy
listPolicy:
 allValues: ALLOW
EOF
    gcloud resource-manager org-policies set-policy $tmpfile --project=${PROJECT_ID}
    rm -rf $tmpfile
done

NETWORK_EXISTS="$(gcloud compute networks list --filter='name~default' --format='value(name)')"

if [[ -z "${NETWORK_EXISTS}" ]]; then
    gcloud compute networks create default \
        --subnet-mode=auto \
        --bgp-routing-mode=global --project=${PROJECT_ID}
fi