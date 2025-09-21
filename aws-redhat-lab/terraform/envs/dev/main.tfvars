region          = "us-east-1"
tf_state_bucket = "a3-redhat-lab-tfstate-dev"
tf_lock_table   = "a3-redhat-lab-tflock-dev"
name_prefix     = "a3-redhat-lab-dev"

key_name             = "a3-redhat-lab-key" # <-- your EC2 key pair name
bastion_cidr_ingress = "108.188.171.70/32" # e.g., "73.12.34.56/32"

instance_counts = {
  bastion      = 1
  aap_ctrl     = 1
  aap_hub      = 1
  aap_eda      = 1
  rhel_targets = 2
  win_targets  = 2
}

# (optional) pin AMIs for reproducibility
rhel_ami_id = "ami-01aaf1c29c7e0f0af"
win_ami_id  = "ami-0e16d075ec2375cf5"
