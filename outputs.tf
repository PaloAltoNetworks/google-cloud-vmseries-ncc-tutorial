output "SSH_VMSERIES_REGION1" {
  description = "Management URL for vmseries in region1"
  value       = "ssh admin@${google_compute_instance.region1_vmseries.network_interface[1].access_config[0].nat_ip} -i ${trim(var.public_key_path, ".pub")}"
}

output "SSH_VMSERIES_REGION2" {
  description = "Management URL for vmseries in region2"
  value       = "ssh admin@${google_compute_instance.region2_vmseries.network_interface[1].access_config[0].nat_ip} -i ${trim(var.public_key_path, ".pub")}"
}


output "SSH_WORKLOAD_VM_REGION1" {
  value       = local.create_workload_vms ? "gcloud compute ssh paloalto@${google_compute_instance.region1_vm[0].name} --zone=${google_compute_instance.region1_vm[0].zone}" : "Workload VMs not created."
  description = "SSH to workload VM in region1"
}

output "SSH_WORKLOAD_VM_REGION2" {
  value       = local.create_workload_vms ? "gcloud compute ssh paloalto@${google_compute_instance.region2_vm[0].name} --zone=${google_compute_instance.region2_vm[0].zone}" : "Workload VMs not created."
  description = "SSH to the workload VM in region2"
}