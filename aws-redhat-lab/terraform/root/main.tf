terraform {
  backend "s3" {
    # These will be passed in at init
  }
}

provider "aws" {
  region = var.region
}

module "network" {
  source   = "../modules/network"
  cidr     = "10.60.0.0/16"
  az_count = 2
  name     = var.name_prefix
}

module "compute" {
  source               = "../modules/compute"
  name                 = var.name_prefix
  region               = var.region
  public_subnet_ids    = module.network.public_subnet_ids
  private_subnet_ids   = module.network.private_subnet_ids
  key_name             = var.key_name
  bastion_cidr_ingress = var.bastion_cidr_ingress
  instance_counts      = var.instance_counts
  rhel_ami_id          = var.rhel_ami_id
  win_ami_id           = var.win_ami_id
}

