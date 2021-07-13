#!/bin/bash
service google-cloud-ops-agent status
if [[ "$?" !=  "0" ]] ; then
  service google-cloud-ops-agent | grep inactive
  if [[ "$?" ==  "1" ]] ; then
    # download script file 
    curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
    # Make the script file executable
    chmod +x add-google-cloud-ops-agent-repo.sh
    # Run the script file
    bash add-google-cloud-ops-agent-repo.sh --also-install
    # Restart the service 
    service google-cloud-ops-agent restart
  fi
fi
 
