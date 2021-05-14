#!/bin/bash

# TODO: Chicken/Egg problem, need to create the GCE instances first and cannot run in Ansible because no inventory exists


    echo "SSH to the box with key to establish key/vm "
    # gcloud compute ssh cnuc-1 --strict-host-key-checking=no --ssh-key-file={{ local_ssh_file }} --zone={{ google_zone }}  --command="whoami"

    # ssh -i ~/.ssh/nucs-garage.pub mensor@<WHATEVER the IP is above>


done




