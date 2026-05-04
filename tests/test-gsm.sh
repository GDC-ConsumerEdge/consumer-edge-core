#!/bin/bash
PROJECT="anthos-bare-metal-lab-1"
REGION="us-west1"
SECRET="gdc-cascade-scm-user"

echo "Checking if secret exists without location..."
gcloud secrets describe $SECRET --project=$PROJECT 

echo "Checking if secret exists with location..."
gcloud secrets describe $SECRET --project=$PROJECT --location=$REGION
