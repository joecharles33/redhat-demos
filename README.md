# AWS Red Hat Lab Environment

This repo contains Infrastructure-as-Code (IaC) and automation playbooks to build a **Red Hat Automation Platform (AAP) lab** on AWS.  
The environment is designed for **quick spin-up demos, PoCs, and personal development** — and can be torn down just as quickly to save costs.  

---

## What You Get
- **Networking (VPC)** with public/private subnets, NAT, and IGW
- **Compute**:
  - Bastion host (jump box with SSH + SSM)
  - Ansible Automation Platform (Controller + Private Automation Hub)
  - Optional AAP EDA Controller
  - RHEL targets
  - Windows targets
- **Terraform** for infra provisioning
- **Ansible** for configuration + AAP installation
- **GitHub-ready structure** for CI/CD pipelines

---

## Prerequisites

Red Hat Subscriptions (RHEL + Ansible Trials)

Both RHEL and Ansible Automation Platform require entitlements. For development and PoCs you can use Red Hat Developer subscriptions and trial licenses.

Get RHEL (Developer Subscription)

Create a Red Hat account with your company's enail and join the Red Hat Developer Program. 

https://developers.redhat.com/

Download RHEL images/ISOs or use AWS Marketplace AMIs provided under your developer subscription.

## Register RHEL instances:

```sudo subscription-manager register --username "<redhat-username>" --password "<redhat-password>"
sudo subscription-manager attach --auto
```

## Get Ansible Automation Platform (Trial License)

Visit the AAP Trial Page
 and click Start my trial.

Sign in with your Red Hat account and request a trial.

Download the installer bundle and license key from your trial success page / email.

Use this license during the AAP install playbooks.



1. **AWS Account**
   - Create an IAM user (e.g. `devops-admin`) with **programmatic access**
   - Attach `AdministratorAccess` for now (restrict later)

2. **Local Tools**
   - AWS CLI
   - Terraform (>= 1.7)
   - Ansible (>= 2.16)
   - Git
   - (Optional) Podman or Docker for Execution Environments

3. **Terraform Remote State**
   - One-time setup in AWS:
     ```bash
     aws s3 mb s3://a3-redhat-lab-tfstate-dev --region us-east-1
     aws dynamodb create-table \
       --table-name a3-redhat-lab-tflock-dev \
       --attribute-definitions AttributeName=LockID,AttributeType=S \
       --key-schema AttributeName=LockID,KeyType=HASH \
       --billing-mode PAY_PER_REQUEST \
       --region us-east-1
     ```

---

## 📂 Repository Layout
aws-redhat-lab/
├── terraform/
│ ├── root/ # main Terraform entrypoint
│ ├── modules/ # reusable modules (network, compute, etc.)
│ └── envs/dev/ # environment-specific variables
├── ansible/
│ ├── inventories/ # host/group inventories
│ ├── playbooks/ # install + demo playbooks
│ └── roles/ # reusable Ansible roles
├── ee/ # execution environment definitions
└── .github/workflows/ # CI/CD pipelines

---

## ⚡ Step-by-Step Setup

### 1. Configure AWS CLI
```bash
aws configure
# Enter your IAM user credentials and default region (e.g. us-east-1)
aws sts get-caller-identity
```

---

## 2. Bootstrap REpo

mkdir -p ~/projects/aws-redhat-lab/{terraform/{root,modules/{network,compute},envs/dev},ansible/{inventories,playbooks,roles}}
cd ~/projects/aws-redhat-lab
git init

---

## 3. Deploy Networking (VPC)

The network module creates:

VPC (10.60.0.0/16)

Public + private subnets across AZs

IGW + NAT

Route tables

Deploy:

```cd terraform/root
terraform init \
  -backend-config="bucket=a3-redhat-lab-tfstate-dev" \
  -backend-config="key=dev/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=a3-redhat-lab-tflock-dev"

terraform plan -var-file=../envs/dev/main.tfvars
terraform apply -var-file=../envs/dev/main.tfvars -auto-approve
```
---

## 4. Deploy Compute

The compute module launches:

Bastion host

AAP Controller + Hub (+ optional EDA)

2× RHEL targets

2× Windows targets

Configure terraform/envs/dev/main.tfvars:

```
region              = "us-east-1"
tf_state_bucket     = "a3-redhat-lab-tfstate-dev"
tf_lock_table       = "a3-redhat-lab-tflock-dev"
name_prefix         = "a3-redhat-lab-dev"

key_name            = "your-ec2-keypair-name"
bastion_cidr_ingress= "YOUR.PUBLIC.IP/32"

instance_counts = {
  bastion      = 1
  aap_ctrl     = 1
  aap_hub      = 1
  aap_eda      = 0
  rhel_targets = 2
  win_targets  = 2
}
```

Then apply again:

```
terraform plan -var-file=../envs/dev/main.tfvars
terraform apply -var-file=../envs/dev/main.tfvars -auto-approve
```

---
## 5. Capture Outputs

Terraform prints:

Bastion public IP

Controller private IP

Hub private IP

RHEL + Windows target IPs

---
## 6. Using the environment 

SSH into Bastion

```

ssh -i ~/.ssh/<your-key>.pem ec2-user@<bastion_public_ip>
```

From Bastion → Controller

```
ssh ec2-user@<controller_private_ip>
```

## Test Ansible Connectivity

Edit ansible/inventories/aws.yml with IPs from Terraform outputs:

```
all:
  children:
    aap:
      hosts:
        controller:
          ansible_host: <controller_private_ip>
          ansible_user: ec2-user
    rhel_targets:
      hosts:
        rhel1: { ansible_host: <rhel_target_1>, ansible_user: ec2-user }
        rhel2: { ansible_host: <rhel_target_2>, ansible_user: ec2-user }
    windows_targets:
      hosts:
        win1: { ansible_host: <win_target_1>, ansible_user: Administrator }
        win2: { ansible_host: <win_target_2>, ansible_user: Administrator }
```

run: 

```
ansible -i ansible/inventories/aws.yml all -m ping
```

## Tear Down

When finished, destroy everything to save costs:

```
cd terraform/root
terraform destroy -var-file=../envs/dev/main.tfvars -auto-approve
```



