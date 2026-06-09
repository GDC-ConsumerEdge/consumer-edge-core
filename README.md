# Consumer Edge Core

Consumer Edge Core is a comprehensive automation framework designed to provision, configure, and scale Google Distributed Cloud Edge (Anthos Bare Metal) clusters. It eliminates the friction of managing distributed edge infrastructure by providing unified deployment workflows for both physical hardware and Google Cloud Compute Engine instances.

## Recent Notifications
* May 8, 2026 and later, code changes require a new Build Container to be built. See **[Build Run/Install Container]** below.

## Quick Start & Installation

### Prerequisites
* Google Cloud CLI (`gcloud`)
* `docker`, `git`, `jq`, `screen`, `direnv`
* Python 3.10+

### Setup One-time
```bash
# 1. Clone the repository
git clone <repository-url>
cd consumer-edge-core

# 2. Install Python dependencies
pip install -r requirements.txt

# 3. Run the initial environment setup script
./setup.sh

# 4. Load environment variables
direnv allow .

# 5. Setup Cluster Configuration
./scripts/instance-context.sh <name>
# Answer 'yes'
./scripts/instance-context.sh -

# 5. Execute the installation playbook
./install.sh
```

#### Build Run/Install Container

Keeping the docker container used in `./install.sh` can be achieved by running `gcloud builds submit --config ./docker-build/cloudbuild.yaml ./ --async --quiet --verbosity=critical --no-user-output-enabled`

> :warning: NOTE: Some Org Policies prevent `gcloud builds` from using non-specific buckets to hold code. Use the following in this case

```
# Create a regional bucket
gsutil mb -l ${REGION} gs://${PROJECT_ID}-cloudbuild-staging

# Kickoff the build
gcloud builds submit \
    --region=[REGION] \
    --gcs-source-staging-dir=gs://${PROJECT_ID}-cloudbuild-staging/source \
    --config ./docker-build/cloudbuild.yaml .
```

## GCP Log Streaming & Customization

The installation container automatically streams structured execution events (playbook starts, task successes, task failures) directly to **Google Cloud Logging (Stackdriver)** inside your `$PROJECT_ID`.

To find these logs in your Google Cloud Console, open the **Logs Explorer** and use the following query:
```query
logName="projects/<your-project-id>/logs/ansible-playbook-runs"
```

### Customization Environment Variables

You can control the stream destination, custom tagging, and logging verbosity inside your container by setting the following environment variables:

| Environment Variable | Default Value | Description |
| :--- | :--- | :--- |
| `ANSIBLE_GCP_LOG_NAME` | `ansible-playbook-runs` | Controls the log bucket/stream name in GCP Logging. |
| `ANSIBLE_GCP_LOG_LEVEL` | `INFO` | Controls logging verbosity. Supported: `INFO` (all events), `NOTICE` (playbook runs & failures), `ERROR` (failures only). |
| `ANSIBLE_GCP_LOG_LABELS` | *(none)* | Comma-separated labels applied directly to each log entry in GCP (e.g., `env=production,site=east`). |

#### Example Usage:
```bash
# Inside the docker container, run with custom name and verbosity:
export ANSIBLE_GCP_LOG_NAME="edge-production-deploys"
export ANSIBLE_GCP_LOG_LEVEL="NOTICE"
export ANSIBLE_GCP_LOG_LABELS="env=prod,site=east_nuc"

ansible-playbook -i inventory site.yml
```

## Features & Capabilities

* **Automated Infrastructure Provisioning**: Deploy Anthos Bare Metal consistently across Google Cloud VMs and physical bare-metal hardware.
* **Declarative Configuration**: Manage complex edge topologies using extensive, ready-to-use Ansible playbooks and inventory templates.
* **Secure by Default**: Integrates seamlessly with Google Secret Manager for SSH key exchanges and secure credential management.
* **Cloud-Native CI/CD**: Includes Docker and Cloud Build configurations for containerized provisioning and reproducible deployments.

## Repository Structure

```text
├── ansible.cfg        # Core Ansible configuration governing playbook execution
├── docker-build/      # Dockerfiles and Cloud Build triggers for the provisioning environment
├── docs/              # Comprehensive documentation and Architectural Decision Records (ADRs)
├── inventory/         # Target definitions and variables for edge site deployments
├── roles/             # Reusable Ansible roles (node readiness, ABM install, cluster validation)
├── scripts/           # Bash utilities for Google Cloud environment preparation and VM setup
├── install.sh         # The primary orchestration script for executing edge deployments
├── setup.sh           # Initializes the workstation, local dependencies, and GCP project
├── site.yml           # The root Ansible playbook for comprehensive cluster installations
```

## Documentation

For detailed instructions on specific workflows, see the `docs/` directory:

*   **[Instance Context Management](docs/INSTANCE-CONTEXT-HOW-TO.md)**: How to create, secure (hydrate/dehydrate), and switch between cluster configurations.
*   **[Hardware Provisioning](docs/HARDWARE_PROVISION.md)**: Setup and baseline installation for physical edge nodes.
*   **[GCP Deployment Guide](docs/README-GCP-Deployment.md)**: Simulating edge environments using Google Compute Engine.

## Tech Stack & Dependencies

| Category | Technology |
| :--- | :--- |
| **Language** | Python, Bash |
| **Core Libs** | Ansible (8.5.0), Jinja2 |
| **Infrastructure** | Google Cloud (GCE, Secret Manager, Cloud Build), Docker, Anthos Bare Metal |
