# Checklist

The following files and/or tasks need to be completed before starting to install

- [ ] `add-hosts` file with contents of hosts (copy `add-hosts-example` to `add-hosts`and replace varaibles)
- [ ] New or correct public/private keypair for hosts access (ie: `ssh-keygen...` or copy both keys as `consumer-edge-machine` and `consumer-edge-machine.pub`)
- [ ] `envrc` variables verified (copy `envrc-example` to `envrc` and replace variables)
  - [ ] Project Name (replaces everywhere necessary)
  - [ ] PAT token for Primary Root Repo
  - [ ] ACM name properly set
- [ ] Replace varaiables in the `gcp-example.yml` and rename to `gcp.yml`
- [ ] `instance-run-vars.yaml` variables set (copy `instance-run-vars-template.yaml` to `instance-run-vars.yaml` and replace values)
  - [ ] ACM name (this is the name of the cluster in your Root Repo)
  - [ ] GDC version (set `abm-version` if overriding the `inventory/group/all.yaml` version)
  - [ ] Storage provider information
- [ ] Correct provisioning GSA value (ie: GSA key for a provisioning GSA with "editor" permissions)
