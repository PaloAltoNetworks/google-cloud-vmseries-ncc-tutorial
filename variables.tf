variable "project_id" {
  description = "GCP project ID"
  default     = null
}

variable "prefix" {
  description = "Arbitrary string used to prefix resource names."
  type        = string
  default     = null
}

variable "region1" {
  description = "Google Cloud region1 for the created resources."
  type        = string
  default     = null
}

variable "region2" {
  description = "Google Cloud region1 for the created resources."
  type        = string
  default     = null
}

variable "public_key_path" {
  description = "Local path to public SSH key.  If you do not have a public key, run >> ssh-keygen -f ~/.ssh/demo-key -t rsa -C admin"
  type        = string
  default     = null
}

variable "vmseries_image" {
  description = "The image name from which to boot an instance, including the license type and the version, e.g. vmseries-byol-814, vmseries-bundle1-814, vmseries-flex-bundle2-1001. Default is vmseries-flex-bundle1-913."
  type        = string
  default     = "https://www.googleapis.com/compute/v1/projects/paloaltonetworksgcp-public/global/images/vmseries-flex-bundle2-1112h3"

}

variable "vmseries_machine_type" {
  description = "The machine type for the VM-Series instance."
  type        = string
  default     = "n2-standard-4"
}

variable "mgmt_allow_ips" {
  description = "A list of IP addresses to be added to the management network's ingress firewall rule. The IP addresses will be able to access to the VM-Series management interface."
  type        = list(string)
  default     = null
}




variable "region1_cidr_mgmt" {
  description = "The CIDR range of the management subnetwork in region1."
  type        = string
  default     = null
}

variable "region1_cidr_untrust" {
  description = "The CIDR range of the untrust subnetwork in region1."
  type        = string
  default     = null
}

variable "region1_cidr_vpc1" {
  description = "The CIDR range of the vpc1 subnetwork in region1."
  type        = string
  default     = null
}

variable "region1_cidr_vpc2" {
  description = "The CIDR range of the vpc2 subnetwork in region1."
  type        = string
  default     = null
}


variable "region2_cidr_mgmt" {
  description = "The CIDR range of the management subnetwork in region2."
  type        = string
  default     = null
}

variable "region2_cidr_untrust" {
  description = "The CIDR range of the untrust subnetwork in region2."
  type        = string
  default     = null
}

variable "region2_cidr_vpc1" {
  description = "The CIDR range of the vpc1 subnetwork in region2."
  type        = string
  default     = null
}

variable "region2_cidr_vpc2" {
  description = "The CIDR range of the vpc2 subnetwork in region2."
  type        = string
  default     = null
}




variable "create_workload_vms" {
  description = "Set to true to create a workload VM for testing purposes."
  default     = true
}

