#!/bin/bash
gsutil hmac create longhorn-cloud-storage@{{ google_project_id }}.iam.gserviceaccount.com > /tmp/hmackey.txt
access_key=`cat  /tmp/hmackey.txt  | awk  -F: '{print $2}' | xargs | awk '{print $1}'`
access_secret=`cat  /tmp/hmackey.txt  | awk  -F: '{print $2}' | xargs | awk '{print $2}'`
echo "{\"access_key\": \"${access_key}\",  \"access_secret\": \"${access_secret}\" , \"endpoint\" : \"https://storage.googleapis.com\" }" > /tmp/hmacsecret.json     
gcloud secrets versions add longhorn-cloud-storage-hmac --data-file="/tmp/hmacsecret.json"
rm -rf /tmp/hmacsecret.json # delete temp file

 
