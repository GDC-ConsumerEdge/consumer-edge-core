# Overview

This is an approach to using `ansible-pull` to provide two primary responsibilites. The operations of `ansible-pull` will be applied at the Operating System level and dependencies/appliations not running inside the cluser.

1. Drift Management - Provide a reguarly running playbook that keeps the OS, certain dependencies, static set of users & groups, disk mounts, network interfaces & configuration, etc. These activites are meant to be only configuration active, any other configuration is overwritten to keep the machine in complance.
1. Operations on specific machines for tasks such as ABM upgrades, ACM/Longhor-or-Robin/ExternalSecrets/CRDs/opeators, remote-SSH tunnel, etc


## Terms & tools

Ansible - Configuration Management tool set that allows declarative syntax setting desired state of a target(s) host systems. Systems with configuration being applied to are often called Inventory and Hosts. Standard ansible configruation is applied as Push configuration

Push Configuration - Method of deploying configuration by logging into system and copying configuration into the target

Pull Configuration - Method of deploying configuration where the target system requests configuration from the centralized configuration and copys it down into the system (Pulls configuration into the host)

Ansible Pull - Standard ansible configuration, but deployed where each host requests configuration from a centralized repository and applied on itself (Pulls configuration and runs on itself). In ansible pull configuration, there is only one host (the target host)

## Drift Management

Drift management is the act of reconsiling a desired state with chagnes that may have happened to the system. The drift management works as a method to apply eventually consistent changes over time as well as mitigating malicious or improper working software.

Each node in the system will run a drift-management oriented  playbook via ansible-pull

1. Establish a configuration git-repository with playbooks for a host(s)
    * Playbook(s) will include:
        * upgrade ABM (TBD, still outstanding challenges)
        * Users &amp; Groups (only specific users/groups can be on the system)
        * Network configuration (IP, netplan, virtual interfaces, etc)
        * Storage configuration (mounts points, permissions on important folders &amp; files)
        * ...
1. Run ansible-pull as `cron` job every 15 minutes (configurable)
    * Check for change in repo since last query, if not, skip
    * Pull down configuration (ansible playbook(s) and tasks)
    * Run playbook(s) & tasks



