output "vpc_id" {
  value = module.network.vpc_id
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.network.private_subnet_ids
}


output "bastion_public_ip" { value = module.compute.bastion_public_ip }
output "aap_controller_private_ips" { value = module.compute.aap_controller_private_ips }
output "aap_hub_private_ips" { value = module.compute.aap_hub_private_ips }
output "aap_eda_private_ips" { value = module.compute.aap_eda_private_ips }
output "rhel_targets_private_ips" { value = module.compute.rhel_targets_private_ips }
output "win_targets_private_ips" { value = module.compute.win_targets_private_ips }

