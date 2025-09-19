output "bastion_public_ip" {
  value = [for e in aws_eip.bastion : e.public_ip]
}

output "aap_controller_private_ips" {
  value = [for i in aws_instance.aap_ctrl : i.private_ip]
}

output "aap_hub_private_ips" {
  value = [for i in aws_instance.aap_hub : i.private_ip]
}

output "aap_eda_private_ips" {
  value = [for i in aws_instance.aap_eda : i.private_ip]
}

output "rhel_targets_private_ips" {
  value = [for i in aws_instance.rhel_target : i.private_ip]
}

output "win_targets_private_ips" {
  value = [for i in aws_instance.win_target : i.private_ip]
}

