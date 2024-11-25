output "instance_ip" {
  value = google_compute_instance.jashan_backend_vm.network_interface[0].access_config[0].nat_ip
}

output "vpc_name" {
  value = google_compute_network.jashan_vpc.name
}
