variable "region" {
  description = "Single pinned region for StackPilot"
  type        = string
}

variable "instance_type" {
  description = "StackPilot must stay micro"
  type        = string
  default     = "t2.micro"
}

variable "api_port" {
  description = "API port exposed publicly (restricted by your IP)"
  type        = number
}

variable "my_ip_cidr" {
  description = "Your public IP in CIDR form, e.g. 41.123.45.67/32"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Path to your SSH public key"
  type        = string
}

variable "ssh_key_name" {
  description = "Name for EC2 key pair"
  type        = string
  default     = "stackpilot"

}

variable "root_volume_gb" {
  description = "Root disk size in GB (keep small)"
  type        = number
  default     = 8

  validation {
    condition     = var.root_volume_gb >= 8 && var.root_volume_gb <= 16
    error_message = "root_volume_gb must be between 8 and 16."
  }
}