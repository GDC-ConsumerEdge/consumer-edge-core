#!/bin/bash
service google-fluentd status
if [[ "$?" !=  "0" ]] ; then
  service google-fluentd | grep inactive
  if [[ "$?" ==  "1" ]] ; then
    # download script file 
    curl -sSO https://dl.google.com/cloudagents/add-logging-agent-repo.sh
    # Make the script file executable
    chmod +x add-logging-agent-repo.sh
    # Run the script file
    bash add-logging-agent-repo.sh --also-install
    if [[ -f "/var/instance_id.txt" ]]
    then
      echo "instance id file exists /var/instance_id.txt."
      random_instance_id=`cat /var/instance_id.txt`
    else
      random_instance_id=`shuf -i 1-1000000000000000000 -n 1`
      echo ${random_instance_id} > /var/instance_id.txt
    fi
    sed "s/INSTANCE_ID/${random_instance_id}/g" /tmp/google-fluentd.conf > /tmp/google-fluentd.conf.backup
    cp /tmp/google-fluentd.conf.backup /etc/google-fluentd/google-fluentd.conf
    cp /tmp/google-fluentd /etc/init.d/google-fluentd
    mv /etc/google-fluentd/config.d/syslog.conf.dpkg-new /etc/google-fluentd/config.d/syslog.conf
    # Restart the service 
    service google-fluentd restart
    systemctl daemon-reload
  fi
fi
 
