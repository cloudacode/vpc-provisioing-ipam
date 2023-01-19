terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.50.0"
    }
  }
  required_version = ">= 1.3.0"

  cloud {
    # terraform cloud org, workspaces name
    organization = "cloudacode"
    workspaces {
      name = "vpc-provisioing-ipam"
    }
  }
}

provider "aws" {
  region = local.region
}

locals {
  region = "us-east-1"
  name   = "cloudacode"
  azs    = ["${local.region}a", "${local.region}b", "${local.region}c"]

  # Calculate subnet cidrs from previewed IPAM CIDR
  preview_partition = cidrsubnets(data.aws_vpc_ipam_preview_next_cidr.this.cidr, 2, 2, 2)
}

# Find the shared Resource Access Manager pool
# Info on RAM sharing pools: https://docs.aws.amazon.com/vpc/latest/ipam/share-pool-ipam.html
data "aws_vpc_ipam_pool" "this" {
  filter {
    name   = "description"
    values = ["cloudacode"]
  }

  filter {
    name   = "address-family"
    values = ["ipv4"]
  }
}

# Preview next CIDR from pool
data "aws_vpc_ipam_preview_next_cidr" "this" {
  ipam_pool_id   = data.aws_vpc_ipam_pool.this.id
  netmask_length = 16
}

################################################################################
# VPC Module
################################################################################

# Provision IPv4 VPC
module "vpc-prod" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${local.name}-prod"

  use_ipam_pool       = true
  ipv4_ipam_pool_id   = data.aws_vpc_ipam_pool.this.id
  ipv4_netmask_length = 16
  azs                 = local.azs

  private_subnets = cidrsubnets(local.preview_partition[0], 2, 2, 2)
  public_subnets  = cidrsubnets(local.preview_partition[1], 2, 2, 2)

  tags = {
    Org = "cloudacode.com"
    Env = "prod"
  }
}

################################################################################
# Output
################################################################################

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}
