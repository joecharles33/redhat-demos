variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "key_name" {
  type = string
}

variable "bastion_cidr_ingress" {
  description = "Your workstation/public IP CIDR (e.g., 73.12.34.56/32)"
  type        = string
}

variable "instance_counts" {
  description = "How many of each node type to launch"
  type = object({
    bastion      = number
    aap_ctrl     = number
    aap_hub      = number
    aap_eda      = number
    rhel_targets = number
    win_targets  = number
  })
}

variable "rhel_instance_type" {
  type    = string
  default = "t3.large"
}

variable "win_instance_type" {
  type    = string
  default = "t3.large"
}

# Optional: pin AMIs; leave empty to auto-select latest marketplace images
variable "rhel_ami_id" {
  type    = string
  default = ""
}

variable "win_ami_id" {
  type    = string
  default = ""
}

# Optional: not strictly needed yet
variable "reports_bucket" {
  type    = string
  default = ""
}

