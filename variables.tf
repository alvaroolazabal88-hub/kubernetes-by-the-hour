variable "alert_email" {
  description = "Email address to receive alarm notifications."
  type        = string
}

variable "tailscale_authkey" {
  type      = string
  sensitive = true
}

variable "node_ami_id" {
  description = "I am using an specific version to prevent recreation of the instance when terraform apply"
  type        = string
  default     = "ami-09179a962fadf762b"
}