## Developing with Ansible

This section is 100% optional and is intended to provide information about how to contribute to this project.  This project is primarly based on Ansible, which has some challenges when developing against a physical server. Lucily, there is Molecule, a tool that established a build lifecycle and supports development using ephemeral Docker containers.

### Using Molecule

If you wish to use Molecule to develop the roles, install the following:

```bash
python -m pip install --user "molecule[ansible,docker,lint,gce]"
# not 100% sure that the above installs the gce provisioner for molecule, so repeat just in case
pip install molecule-gce
```

### Creating a new module

1. Navigate to the `roles/` folder.

1. Create a new module
    ```bash
    molecule init role
    ```
1. Modify the `README.md` with appropriate details

1. Use `setup-kvm` or `google-tools` as reference for setting up Molecule (see folder `molecule/` to see docker config)

1. Remove any un-used folders

### Testing Role in isolation

1. Navigate to the role folder

1. Verify configuration has been setup for Molecule (ie, there's a `/molecule` folder)

    > NOTE: Sometimes the Docker image needs to be pulled prior to running tests/converge

1. Start the molecule provionsed Docker imgae

    ```bash
    molecule create
    ```

1. Run `moleclue converge` to run isolated test (see "Specific Scenarios" to target individual scenarios). This command can (and often should) be run over and over during development.

1. Clean up by removing the Docker container used by Molecule

    ```bash
    molecule destroy
    ```

### Specific Scenarios

Some molecule tests have multiple "scenarios", use the following for specific scenario. This is applicapble for ALL `molecule` commands.

Example use: 

```bash
molecule create -s <scenario-name>
```

### Roles with "systemd"

`systemd` by default is not enabled for Docker images. In order to start a systemd process the Docker image needs to reference the host machine (ie. the developers machine) `cgroups` folders.

Here is an example of using the public Ubuntu docker image and mounting `cgropus` into the image. Note, this uses Dockerfile (see below)

```yaml
dependency:
  name: galaxy
driver:
  name: docker
platforms:
  - name: machine-1
    dockerfile: Dockerfile.j2 # important to add missing dependencies
    image: ubuntu
    image_version: latest
    pre_build_image: false
    privileged: True ## REQUIRED for cgroups
    volume_mounts:
      - "/sys/fs/cgroup:/sys/fs/cgroup:rw" # MOUNT cgroups from host computer
    command: "/sbin/init"
provisioner:
  name: ansible
  inventory:
    host_vars:
      machine-1: # matches platforms[0].name
        var_name: "var value"
verifier:
  name: ansible
```

### Custom images & missing dependencies

Sometimes there are perfect Docker images that contain all of the dependencies needed so they represent the target inventory machines. Most of the time, this is not true.

Target Docker images require a few primary dependencies so Ansible can be used to provision them. Any docker image can be used as a base and enahnced using a `Dockerfile` to generate a custom docker image locally.

#### Required Dependencies
* Python 3
* Python 3 as Python (helps with not mixing up `python3` and `pip3`)

