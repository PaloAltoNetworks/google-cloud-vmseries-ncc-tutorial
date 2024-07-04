# ----------------------------------------------------------------------------------------------------------------
# Create subnets in region2.
# ----------------------------------------------------------------------------------------------------------------

resource "google_compute_subnetwork" "region2_mgmt" {
  name          = "${google_compute_network.mgmt.name}-${local.region2}"
  network       = google_compute_network.mgmt.id
  ip_cidr_range = local.region2_cidr_mgmt
  region        = local.region2
}

resource "google_compute_subnetwork" "region2_untrust" {
  name          = "${google_compute_network.untrust.name}-${local.region2}"
  network       = google_compute_network.untrust.id
  ip_cidr_range = local.region2_cidr_untrust
  region        = local.region2
}

resource "google_compute_subnetwork" "region2_vpc1" {
  name          = "${google_compute_network.vpc1.name}-${local.region2}"
  network       = google_compute_network.vpc1.id
  ip_cidr_range = local.region2_cidr_vpc1
  region        = local.region2
}


# ----------------------------------------------------------------------------------------------------------------
# Create VPC1 cloud router within region2. 
# ----------------------------------------------------------------------------------------------------------------

// Create cloud router in vpc1 region2.
resource "google_compute_router" "region2_vpc1" {
  name    = "cr-${google_compute_network.vpc1.name}-${local.region2}"
  network = google_compute_network.vpc1.id
  region  = local.region2
  bgp {
    asn            = local.cr_asn
    advertise_mode = "DEFAULT"
  }
}

// Create primary BGP interface on the cloud router.
resource "google_compute_router_interface" "region2_nic0" {
  name                = "${google_compute_router.region2_vpc1.name}-nic0"
  router              = google_compute_router.region2_vpc1.name
  region              = google_compute_router.region2_vpc1.region
  subnetwork          = google_compute_subnetwork.region2_vpc1.self_link
  private_ip_address  = local.region2_cr_vpc1_peer0
  redundant_interface = google_compute_router_interface.region2_nic1.name
}

// Create backup BGP interface on the cloud router.
resource "google_compute_router_interface" "region2_nic1" {
  name               = "${google_compute_router.region2_vpc1.name}-nic1"
  router             = google_compute_router.region2_vpc1.name
  region             = google_compute_router.region2_vpc1.region
  subnetwork         = google_compute_subnetwork.region2_vpc1.self_link
  private_ip_address = local.region2_cr_vpc1_peer1
}

// Create bgp peer0 using the primary cloud router interface.
resource "google_compute_router_peer" "region2_cr_peer0" {
  name                      = "${google_compute_router.region2_vpc1.name}-peer0"
  router                    = google_compute_router.region2_vpc1.name
  region                    = google_compute_router.region2_vpc1.region
  interface                 = google_compute_router_interface.region2_nic0.name
  router_appliance_instance = google_compute_instance.region2_vmseries.self_link
  peer_ip_address           = google_compute_instance.region2_vmseries.network_interface[2].network_ip
  peer_asn                  = local.fw_asn

  depends_on = [
    google_network_connectivity_spoke.region2_vmseries
  ]
}

// Create bgp peer1 using the backup cloud router interface.
resource "google_compute_router_peer" "region2_cr_peer1" {
  name                      = "${google_compute_router.region2_vpc1.name}-peer1"
  router                    = google_compute_router.region2_vpc1.name
  region                    = google_compute_router.region2_vpc1.region
  interface                 = google_compute_router_interface.region2_nic1.name
  router_appliance_instance = google_compute_instance.region2_vmseries.self_link
  peer_ip_address           = google_compute_instance.region2_vmseries.network_interface[2].network_ip
  peer_asn                  = local.fw_asn

  depends_on = [
    google_network_connectivity_spoke.region2_vmseries
  ]
}

// Retrieve zones in region2.
data "google_compute_zones" "region2" {
  region = local.region2
}

// Set values within bootstrap.xml for region2 vmseries.
data "template_file" "region2_bootstrap" {
  template = file("bootstrap_files/bootstrap.xml.template")
  vars = {
    fw_gw_untrust = google_compute_subnetwork.region2_untrust.gateway_address # 10.0.1.1
    fw_asn        = local.fw_asn                                              # 65001
    fw_ip_vpc1    = local.region2_fw_ip_vpc1                                  # 10.1.0.2
    cr_asn        = local.cr_asn                                              # 65000
    cr_peer0      = local.region2_cr_vpc1_peer0                               # 10.1.0.10
    cr_peer1      = local.region2_cr_vpc1_peer1                               # 10.1.0.11
  }
}

// Write values to tmp/bootstrap.xml for region2 vmseries.
resource "local_file" "region2_bootstrap" {
  filename = "tmp/bootstrap-${local.region2}"
  content  = data.template_file.region2_bootstrap.rendered
}

// Create bootstrap storage bucket for region2 vmseries.
module "region2_bootstrap" {
  source          = "PaloAltoNetworks/swfw-modules/google//modules/bootstrap"
  version         = "~> 2.0"
  location        = "US"
  service_account = module.iam_service_account.email
  files = {
    "bootstrap_files/init-cfg.txt.sample" = "config/init-cfg.txt"
    "tmp/bootstrap-${local.region2}"      = "config/bootstrap.xml"
    "bootstrap_files/authcodes"           = "license/authcodes"
  }

  depends_on = [
    local_file.region2_bootstrap
  ]
}

resource "google_compute_instance" "region2_vmseries" {
  name                      = "${local.prefix}vmseries-${local.region2}"
  machine_type              = local.vmseries_machine_type
  zone                      = data.google_compute_zones.region2.names[0]
  can_ip_forward            = true
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = local.vmseries_image
      type  = "pd-standard"
    }
  }

  metadata = {
    mgmt-interface-swap                  = "enable"
    serial-port-enable                   = true
    ssh-keys                             = "admin:${file(local.public_key_path)}"
    vmseries-bootstrap-gce-storagebucket = module.region2_bootstrap.bucket_name
  }

  // nic0 - untrust nic
  network_interface {
    subnetwork = google_compute_subnetwork.region2_untrust.self_link
    access_config {}
  }

  // nic1 - mgmt
  network_interface {
    subnetwork = google_compute_subnetwork.region2_mgmt.self_link
    access_config {}
  }

  // nic2 - vpc1 
  network_interface {
    subnetwork = google_compute_subnetwork.region2_vpc1.self_link
    network_ip = local.region2_fw_ip_vpc1
  }

  service_account {
    email = module.iam_service_account.email
    scopes = [
      "https://www.googleapis.com/auth/compute.readonly",
      "https://www.googleapis.com/auth/cloud.useraccounts.readonly",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write"
    ]
  }

  depends_on = [
    module.region2_bootstrap
  ]
}


# ----------------------------------------------------------------------------------------------------------------
# Set vmseries in region2 as a NCC router appliance spoke.
# ----------------------------------------------------------------------------------------------------------------

// Create NCC router appliance spoke for VPC1 region2.
resource "google_network_connectivity_spoke" "region2_vmseries" {
  name     = "${google_compute_instance.region2_vmseries.name}-spoke"
  hub      = google_network_connectivity_hub.main.id
  location = local.region2
  linked_router_appliance_instances {
    site_to_site_data_transfer = false
    instances {
      virtual_machine = google_compute_instance.region2_vmseries.self_link
      ip_address      = google_compute_instance.region2_vmseries.network_interface[2].network_ip
    }
  }
}

# ----------------------------------------------------------------------------------------------------------------
# If `create_workload_vms = true`, create workload VMs in vpc1.
# ----------------------------------------------------------------------------------------------------------------

resource "google_compute_instance" "region2_vm" {
  count                     = (local.create_workload_vms ? 1 : 0)
  name                      = "${local.prefix}${local.region2}-vm"
  machine_type              = "n2-standard-2"
  zone                      = data.google_compute_zones.region2.names[0]
  can_ip_forward            = false
  allow_stopping_for_update = true

  metadata = {
    serial-port-enable = true
  }

  network_interface {
    subnetwork = google_compute_subnetwork.region2_vpc1.self_link
    network_ip = cidrhost(var.region2_cidr_vpc1, 5)
  }

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
    }
  }
}