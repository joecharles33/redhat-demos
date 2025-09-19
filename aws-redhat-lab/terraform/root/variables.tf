variable "region" { type = string }
variable "tf_state_bucket" { type = string }
variable "tf_lock_table" { type = string }
variable "name_prefix" { type = string }

variable "key_name" { type = string }
variable "bastion_cidr_ingress" { type = string }
variable "instance_counts" {
  type = object({
    bastion : number
    aap_ctrl : number
    aap_hub : number
    aap_eda : number
    rhel_targets : number
    win_targets : number
  })
}
variable "rhel_ami_id" {
  type    = string
  default = ""
}
variable "win_ami_id" {
  type    = string
  default = ""
}
