terraform {
  required_version = ">= 0.15.3, < 2.0"
}

provider "google" {
  project = local.project_id
  region  = local.region1
}

provider "google-beta" {
  project = local.project_id
  region  = local.region1
}


# ----------------------------------------------------------------------------------------------------------------
# Local variables
# ----------------------------------------------------------------------------------------------------------------

locals {
  prefix                = var.prefix != null && var.prefix != "" ? "${var.prefix}-" : ""
  project_id            = var.project_id
  public_key_path       = var.public_key_path
  mgmt_allow_ips        = var.mgmt_allow_ips
  create_workload_vms   = true
  vmseries_machine_type = var.vmseries_machine_type
  vmseries_image        = "https://www.googleapis.com/compute/v1/projects/paloaltonetworksgcp-public/global/images/${var.vmseries_image}"
  fw_asn                = 65001
  cr_asn                = 65000
  region1               = var.region1
  region1_cidr_mgmt     = var.region1_cidr_mgmt
  region1_cidr_untrust  = var.region1_cidr_untrust
  region1_cidr_vpc1     = var.region1_cidr_vpc1
  region1_fw_ip_vpc1    = cidrhost(local.region1_cidr_vpc1, 2)
  region1_cr_vpc1_peer0 = cidrhost(local.region1_cidr_vpc1, 10)
  region1_cr_vpc1_peer1 = cidrhost(local.region1_cidr_vpc1, 11)
  region2               = var.region2
  region2_cidr_mgmt     = var.region2_cidr_mgmt
  region2_cidr_untrust  = var.region2_cidr_untrust
  region2_cidr_vpc1     = var.region2_cidr_vpc1
  region2_fw_ip_vpc1    = cidrhost(local.region2_cidr_vpc1, 2)
  region2_cr_vpc1_peer0 = cidrhost(local.region2_cidr_vpc1, 10)
  region2_cr_vpc1_peer1 = cidrhost(local.region2_cidr_vpc1, 11)
}

# ----------------------------------------------------------------------------------------------------------------
# Create NCC Hub.
# ----------------------------------------------------------------------------------------------------------------

resource "google_network_connectivity_hub" "main" {
  name = "${local.prefix}hub"
}

# ----------------------------------------------------------------------------------------------------------------
# Create VPC networks.
# ----------------------------------------------------------------------------------------------------------------

resource "google_compute_network" "mgmt" {
  name                    = "${local.prefix}mgmt"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
}

resource "google_compute_network" "untrust" {
  name                    = "${local.prefix}untrust"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
}

resource "google_compute_network" "vpc1" {
  name                            = "${local.prefix}vpc1"
  auto_create_subnetworks         = false
  routing_mode                    = "GLOBAL"
  delete_default_routes_on_create = true
}


# ----------------------------------------------------------------------------------------------------------------
# Create an ingress firewall rules in each VPC.
# ----------------------------------------------------------------------------------------------------------------

resource "google_compute_firewall" "mgmt" {
  name          = "${google_compute_network.mgmt.name}-ingress"
  network       = google_compute_network.mgmt.name
  source_ranges = local.mgmt_allow_ips

  allow {
    protocol = "tcp"
    ports    = ["443", "22", "3978"]
  }
}

resource "google_compute_firewall" "untrust" {
  name          = "${google_compute_network.untrust.name}-ingress"
  network       = google_compute_network.untrust.name
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "all"
    ports    = []
  }
}

resource "google_compute_firewall" "vpc1" {
  name          = "${google_compute_network.vpc1.name}-ingress"
  network       = google_compute_network.vpc1.name
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "all"
    ports    = []
  }
}

# ----------------------------------------------------------------------------------------------------------------
# Create service account for vmseries firewalls
# ----------------------------------------------------------------------------------------------------------------

module "iam_service_account" {
  source             = "PaloAltoNetworks/vmseries-modules/google//modules/iam_service_account/"
  service_account_id = "${local.prefix}vmseries-sa"
  project_id         = local.project_id
}