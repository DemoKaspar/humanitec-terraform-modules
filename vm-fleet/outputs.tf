output "loadbalancer_ip" {
  description = "Load balancer DNS name"
  value       = aws_lb.vm_fleet.dns_name
}

output "ssh_private_key" {
  description = "Private SSH key for instance access"
  value       = tls_private_key.ssh.private_key_pem
  sensitive   = true
}

output "ssh_username" {
  description = "SSH username for instance access"
  value       = "ubuntu"
}

output "instance_ips" {
  description = "Private IP addresses of instances"
  value       = []  # ASG instances don't have predictable IPs
}