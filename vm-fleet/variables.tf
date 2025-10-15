# Variables for VM Fleet Module

variable "instance_count" {
  type        = number
  default     = 2
  description = "Number of EC2 instances to create"
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "EC2 instance type"
}

variable "startup_script" {
  type        = string
  default     = ""
  description = "User data script to run on instance startup"
}

variable "app_id" {
  type        = string
  default     = "todo-app"
  description = "Application ID for tagging"
}

variable "env_id" {
  type        = string
  default     = "dev"
  description = "Environment ID for tagging"
}

variable "container_image" {
  description = "Container image to deploy"
  type        = string
  default     = "ghcr.io/demokaspar/fresh-todo-app:latest"
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 3000
}