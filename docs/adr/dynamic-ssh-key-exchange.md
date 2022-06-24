# Overivew

This is a very preliminary idea to async exchange SSH keys on a short-term basis to gain SSH access to a host/node computer in a clsuter.

## Approaches

- Obtain a reverse ssh tunnel
- Swap keys via GCP Secret Manager (or public key via ansible-pull)

## Definitions
* Cluster Machine - Node/Node in on-site cluster
* Service Machine - Cloud GCE instance that acts as the service user's computer

## Steps (logical)

### Initiate Reverse SSH Tunnel

1. Create Service Machine GCE
1. Add/Update playbook for Cluster Machine (TBD on specifics)
    * Ansible Role issuing reverse ssh connection
    * Pass IP & user information of Service Machine user (public key)
    * Possibly create asymetric key on-the-fly, passing public key to Cluster Machine via Ansible Pull

### Perform Reverse SSH Tunnel

1. Remote Server runs playbook role
    * `ssh -R <sm-port>:localhost:22 <user>@<customer-service-machine>`
    * Should be passwordless based on the variables in the playbook (public key, username and Service Machine IP)
    * Any failure, log to syslog (label/attribute/annotate entry for CloudOps later)
    * Possibly set up a user w/ established password (or passed in requested password) or pull private key from GCP Secrets Manager
        * If setting up a user, perhaps give or setup with group that can only run certain commands?
1. Connection should be established from Cluster Machine to Service Machine

### Establish SSH back to Cluster Machine

1. Service machine issues command `ssh <established-user or abm-admin>@localhost -i <private-key-from-above> -p <sm-port>` (or use password)
1. Issue commands on Cluster Machine
1. Exit when done (or optionally kill the process of the reverse tunnel?)

### Cleanup

1. Upon exit, issue a new commit to the git-repo for ansible-pull
    * Cluser Machine removes session
    * Removes temp user if created a temp user


