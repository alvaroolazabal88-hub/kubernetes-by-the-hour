variable "alert_email" {
  description = "Email address to receive alarm notifications."
  type        = string
}

variable "tailscale_authkey" {
  type      = string
  sensitive = true
}