#!/bin/bash

# Define the array of domains
domains=(
    "anthos.googleapis.com"
    "anthosaudit.googleapis.com"
    "anthosgke.googleapis.com"
    "cloudresourcemanager.googleapis.com"
    "connectgateway.googleapis.com"
    "container.googleapis.com"
    "edgecontainer.googleapis.com"
    "gkeconnect.googleapis.com"
    "gkehub.googleapis.com"
    "gkeonprem.googleapis.com"
    "iam.googleapis.com"
    "kubernetesmetadata.googleapis.com"
    "logging.googleapis.com"
    "monitoring.googleapis.com"
    "oauth2.googleapis.com"
    "opsconfigmonitoring.googleapis.com"
    "serviceusage.googleapis.com"
    "stackdriver.googleapis.com"
    "storage.googleapis.com"
    "sts.googleapis.com"
)

resolved=()
not_resolved=()

echo "Checking domain resolution..."

for domain in "${domains[@]}"; do
    # nslookup returns 0 on success, non-zero on failure
    if nslookup "$domain" > /dev/null 2>&1; then
        resolved+=("$domain")
    else
        not_resolved+=("$domain")
    fi
done

echo -e "\n--- Summary ---"

echo -e "\n[RESOLVED]"
if [ ${#resolved[@]} -eq 0 ]; then
    echo "None"
else
    printf '%s\n' "${resolved[@]}"
fi

echo -e "\n[NOT-RESOLVED]"
if [ ${#not_resolved[@]} -eq 0 ]; then
    echo "None"
else
    printf '%s\n' "${not_resolved[@]}"
fi
