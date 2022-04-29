/**
 * Copyright 2018 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/******************************************
  Provider configuration
 *****************************************/
module "project-services" {
  source                      = "git::https://github.com/terraform-google-modules/terraform-google-project-factory.git"
  random_project_id       = true
  name                    = "retail-lab-demo"
  org_id                  = var.organization_id
  billing_account         = var.billing_account
  default_service_account = "keep"

  activate_apis = [
    "binaryauthorization.googleapis.com", //For sec tests?
    "cloudresourcemanager.googleapis.com", //Cloud Resource Manager
    "compute.googleapis.com", //GCE for Bhost and VMs
    "container.googleapis.com", //GKE for Connector
    "containerregistry.googleapis.com", //for Cloud Build to store stuff
    "cloudbuild.googleapis.com", // Cloud Build API to make containers
    "cloudkms.googleapis.com", //KMS for keys
    "secretmanager.googleapis.com", //Secrets Manager
    "storage.googleapis.com", //Google Cloud Storage
    "anthos.googleapis.com", //Anthos API
    "anthosgke.googleapis.com" //GKE Connector
  ]
 disable_services_on_destroy = true
}

module "vpc" {
source                        = "git::https://github.com/terraform-google-modules/terraform-google-network.git"
project_id                    = module.project-services.project_id
auto_create_subnetworks       = false
network_name                  = "default"
mtu                           = 1460
routing_mode                  = "GLOBAL"

subnets = [
        {
            subnet_name               = "default"
            subnet_ip                 = "10.128.0.0/20"
            subnet_region             = "us-central1"
            subnet_private_access     = "true"
            subnet_flow_logs          = "true"
            subnet_flow_logs_sampling = 0.7
            subnet_flow_logs_metadata = "INCLUDE_ALL_METADATA"
        },
]
routes = [ {
      name              = "egress-internet"
      description       = "route through IGW to access internet"
      destination_range = "0.0.0.0/0"
      tags              = "egress-inet"
      next_hop_internet = "true"
    }]
}

module "cloud_router_nat" {
  source                    = "git::https://github.com/terraform-google-modules/terraform-google-cloud-router.git"
  project                   = module.project-services.project_id # Replace this with your project ID in quotes
  name                      = "my-cloud-router"
  network                   = "default"
  region                    = "us-central1"
  nats = [{
    name = "egress"
  }]
  depends_on = [module.vpc.network_name]
}

resource "google_compute_firewall" "allow-ping" {
  name    = "default-ping"
  network = module.vpc.network_name
  project = module.project-services.project_id
  priority = 900

  allow {
    protocol = "icmp"
  }

  # Allow traffic from everywhere to instances with an http-server tag
  source_ranges = ["0.0.0.0/0"]
  target_tags   = []
}

resource "google_compute_firewall" "in-from10" {
  name    = "ingress-10"
  network = module.vpc.network_name
  project = module.project-services.project_id
  priority = 900

  allow {
    protocol = "all"
  }

  # Allow traffic from everywhere to instances with an http-server tag
  source_ranges = ["10.0.0.0/8"]
  target_tags   = []
}


resource "google_compute_firewall" "egress" {
  name    = "egress"
  network = module.vpc.network_name
  project = module.project-services.project_id
  priority = 900
  allow {
    protocol = "all"
  }

  # Allow traffic from everywhere to instances with an http-server tag
  source_ranges = []
  direction = "EGRESS"
  target_tags   = []
}


