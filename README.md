# Consumer Edge Core

Consumer Edge Core is a comprehensive automation framework designed to provision, configure, and scale Google Distributed Cloud Edge (Anthos Bare Metal) clusters. It eliminates the friction of managing distributed edge infrastructure by providing unified deployment workflows for both physical hardware and Google Cloud Compute Engine instances.

## Quick Start & Installation

### Prerequisites
* Google Cloud CLI (`gcloud`)
* `docker`, `git`, `jq`, `screen`, `direnv`
* Python 3.10+

### Setup
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

# 5. Execute the installation playbook
./install.sh
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
└── site.yml           # The root Ansible playbook for comprehensive cluster installations
```

## Tech Stack & Dependencies

| Category | Technology |
| :--- | :--- |
| **Language** | Python, Bash |
| **Core Libs** | Ansible (8.5.0), Jinja2 |
| **Infrastructure** | Google Cloud (GCE, Secret Manager, Cloud Build), Docker, Anthos Bare Metal |
