terraform {
  required_providers {
    ansible = {
      source  = "ansible/ansible"
      version = "~> 1.3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

# Input variables (these will be passed by Humanitec)
variable "vm_fleet_outputs" {
  description = "Outputs from the VM fleet resource"
  type = object({
    instance_ips      = list(string)
    ssh_private_key   = string
    ssh_username      = string
    loadbalancer_ip   = string
  })
}

variable "workload_spec" {
  description = "Workload specification from Humanitec"
  type = object({
    image       = string
    environment = map(string)
    ports       = map(number)
  })
}

# Generate SSH key file
resource "local_sensitive_file" "ssh_key" {
  content         = var.vm_fleet_outputs.ssh_private_key
  filename        = "${path.module}/ssh_key.pem"
  file_permission = "0600"
}

# Generate Docker Compose file
resource "local_file" "docker_compose" {
  content = yamlencode({
    version = "3.8"
    services = {
      app = {
        image = var.workload_spec.image
        environment = var.workload_spec.environment
        ports = [for external_port, internal_port in var.workload_spec.ports : "${external_port}:${internal_port}"]
        restart = "unless-stopped"
        healthcheck = {
          test = ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:${var.workload_spec.ports["80"] || "3000"}/health || exit 1"]
          interval = "30s"
          timeout = "10s"
          retries = 3
        }
      }
    }
  })
  filename = "${path.module}/docker-compose.yml"
}

# Generate Ansible inventory
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tpl", {
    instance_ips = var.vm_fleet_outputs.instance_ips
    ssh_username = var.vm_fleet_outputs.ssh_username
    ssh_key_file = local_sensitive_file.ssh_key.filename
  })
  filename = "${path.module}/inventory.ini"
}

# Deploy workload using Ansible
resource "ansible_playbook" "deploy_workload" {
  playbook   = "${path.module}/deploy-workbook.yml"
  name       = "Deploy workload to VMs"
  
  extra_vars = {
    compose_file_content = local_file.docker_compose.content
    loadbalancer_ip = var.vm_fleet_outputs.loadbalancer_ip
  }

  depends_on = [
    local_file.ansible_inventory,
    local_file.docker_compose,
    local_sensitive_file.ssh_key
  ]
}