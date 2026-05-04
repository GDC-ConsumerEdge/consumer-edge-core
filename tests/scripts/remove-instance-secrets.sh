#!/bin/bash
# Copyright 2026 Google LLC
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

if [[ -z "$1" ]]; then
    echo "Usage: $0 <instance-name> [project-id]"
    echo "Example: $0 cascade my-gcp-project"
    exit 1
fi

INSTANCE_NAME="$1"
PROJECT_ID="$2"

if [[ -z "$PROJECT_ID" ]]; then
    # Try to infer from gcloud config if not provided
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
    if [[ -z "$PROJECT_ID" ]]; then
        echo "Error: Project ID not provided and could not be inferred from gcloud config."
        exit 1
    fi
    echo "Using inferred Project ID: $PROJECT_ID"
fi

echo "WARNING: This will permanently delete ALL secrets starting with 'gdc-${INSTANCE_NAME}-' from project '${PROJECT_ID}'."
echo -n "Are you sure? (y/N): "
read answer
if [[ "$answer" != "y" ]]; then
    echo "Aborted."
    exit 0
fi

# Find all secrets matching the pattern
secrets=$(gcloud secrets list --project="$PROJECT_ID" --filter="name ~ gdc-${INSTANCE_NAME}-.*" --format="value(name)")

if [[ -z "$secrets" ]]; then
    echo "No secrets found matching 'gdc-${INSTANCE_NAME}-*' in project '$PROJECT_ID'."
    exit 0
fi

echo "Found the following secrets to delete:"
echo "$secrets"
echo "----------------------------------------"

for secret in $secrets; do
    # gcloud secrets list returns the full path (projects/.../secrets/name), we just need the name
    secret_name=$(basename "$secret")
    echo "Deleting secret: $secret_name"
    # Using --quiet to bypass the individual deletion prompts
    gcloud secrets delete "$secret_name" --project="$PROJECT_ID" --quiet
    if [[ $? -eq 0 ]]; then
        echo "Successfully deleted $secret_name"
    else
        echo "Failed to delete $secret_name"
    fi
done

echo "Secret removal complete."