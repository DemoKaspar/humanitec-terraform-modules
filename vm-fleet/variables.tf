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
  description = "Application ID for tagging"
}

variable "env_id" {
  type        = string
  description = "Environment ID for tagging"
}