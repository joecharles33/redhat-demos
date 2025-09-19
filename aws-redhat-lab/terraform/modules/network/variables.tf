variable "cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "az_count" {
  description = "How many Availability Zones to spread across"
  type        = number
}

variable "name" {
  description = "Prefix for resource names"
  type        = string
}

