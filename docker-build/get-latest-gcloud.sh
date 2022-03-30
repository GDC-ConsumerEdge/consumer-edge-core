#!/bin/bash

# Flag for Is this a local run (non gcloud)
IS_LOCAL=${1:-false}

echo "Run On Local Machine = ${IS_LOCAL} <-- value"


# store temp files in temp directory
if [[ ${IS_LOCAL} == false ]]; then
    TEMP_DIR="."
else
    TEMP_DIR=$(mktemp -d -t docker-XXXXXXXXXX)
fi
echo "Temp directory: ${TEMP_DIR}"

# URL to the latest
LATEST_SDK_LINE=$(gsutil ls -l gs://cloud-sdk-release/google-cloud-sdk-*-linux-x86_64.tar.gz | sort -k 2 | tail -n 2 | head -1 | awk '{ print $NF }')
echo $LATEST_SDK_LINE >> ${TEMP_DIR}/version-with-url.txt

### Match/extract version
SDK_VERSION_URL=$(cat ${TEMP_DIR}/version-with-url.txt)
SDK_VERSION_REGEX="([0-9.])+"

if [[ ${SDK_VERSION_URL} =~ ${SDK_VERSION_REGEX} ]]; then
    echo ${BASH_REMATCH[0]} >> ${TEMP_DIR}/version.txt
else
    echo "SDK Version could not be determined!"
    exit 1
fi

## Verify version exists
if [[ ! -f "${TEMP_DIR}/version.txt" ]]; then
    echo "Version file was not created"
    exit 1
elif [[ ${IS_LOCAL} == true ]]; then
    VERSION=$(cat ${TEMP_DIR}/version.txt | xargs)
    echo "Using GCLOUD VERSION: '${VERSION}'"
    set -x
    docker build --build-arg="GCLOUD_VERSION=${VERSION}" -t consumer-edge-install .
fi

if [[ -d "${TEMP_DIR}" ]] && [[ ${IS_LOCAL} == true ]]; then
    echo "Removing temp directory"
    ls -al ${TEMP_DIR}
    rm -rf ${TEMP_DIR}
fi
