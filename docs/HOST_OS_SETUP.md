# Overview

This page describes how to setup the basline image on a HostOS
1. Manual HostOS setup (for each host machine)
    1. Install Ubuntu 22.04LTS
    1. Add a user `abm-admin` with a known password for your safe keeping
    1. Setup user for passwordless `sudoer` access (see Internet for options)
    1. Setup networking to establish a Static IP. IPs should be reserved. IPs should also be a contigous range (ie: 192.168.3.11, 192.168.3.12, 192.168.3.13...)
        * Each host should have a short hostname (ie: edge-1, edge-2, edge-3)
    1. Use the public key established in Section 1 (`build-artifacts/consumer-edge-machine.pub`) to establish a passwordless SSH
        ```bash
        ssh-copy-id -i build-artifacts/consumer-edge-machine.pub abm-admin@<hostname>
        ```
        > NOTE: Use the password established when creating the user
    1. Add all of the hosts to `/etc/hosts` or to DNS service available to the provisioning machine
