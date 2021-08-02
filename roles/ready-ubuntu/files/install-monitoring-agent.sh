#!/bin/bash
service stackdriver-agent status
if [[ "$?" !=  "0" ]] ; then
  service stackdriver-agent | grep inactive
  if [[ "$?" ==  "1" ]] ; then
    # download script file 
    curl -sSO https://dl.google.com/cloudagents/add-monitoring-agent-repo.sh
    # Make the script file executable
    chmod +x add-monitoring-agent-repo.sh
    # Run the script file
    bash add-monitoring-agent-repo.sh --also-install
    #TODO Figure out a solution to get a random instance ID and correct zone. 
    if [[ -f "/var/instance_id.txt" ]]
    then
      echo "instance id file exists /var/instance_id.txt."
      random_instance_id=`cat /var/instance_id.txt`
    else
      random_instance_id=`shuf -i 1-1000000000000000000 -n 1`
      echo ${random_instance_id} > /var/instance_id.txt
    fi

    sed "s/INSTANCE_ID/${random_instance_id}/g" /tmp/collectd.conf > /tmp/collectd.conf.backup
    cp /tmp/collectd.conf.backup /etc/stackdriver/collectd.conf
    cp /tmp/stackdriver-agent /etc/init.d/stackdriver-agent  
    # Restart the service 
    service stackdriver-agent restart
    systemctl daemon-reload
  fi
fi
 
