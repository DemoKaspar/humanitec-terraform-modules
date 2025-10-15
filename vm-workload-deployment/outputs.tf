output "deployment_status" {
  description = "Status of the workload deployment"
  value = "Workload deployed successfully"
}

output "application_url" {
  description = "URL where the application is accessible"
  value = "http://${var.vm_fleet_outputs.loadbalancer_ip}"
}