locals {
  tags = {
    Environment = var.environment
    CostCenter  = var.cost_center
    ManagedBy   = "terraform"
    Project     = "multicloud-gitops-platform"
  }
}

data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.13"

  name = "multicloud-gitops-vpc"
  cidr = "10.60.0.0/16"

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = ["10.60.0.0/20", "10.60.16.0/20"]
  public_subnets  = ["10.60.128.0/20", "10.60.144.0/20"]

  enable_nat_gateway   = true
  single_nat_gateway   = true # cost-conscious: one NAT GW instead of one per AZ
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = local.tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = var.cluster_name
  cluster_version = "1.30"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = false # Jenkins sits in the public subnet with its own SG,
  # not the one EKS auto-allows to reach the private endpoint's IP — keep DNS
  # resolving only to the public endpoint to avoid that entirely.

  # Pinned to match the real cluster's actual value (set implicitly when it
  # was first created) — the module's current default differs, which would
  # otherwise force a full cluster replacement for a flag that doesn't
  # actually matter for this single-cluster demo.
  bootstrap_self_managed_addons = false

  authentication_mode = "API_AND_CONFIG_MAP"

  access_entries = {
    jenkins = {
      principal_arn = aws_iam_role.jenkins.arn
      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }

  eks_managed_node_groups = {
    default = {
      instance_types = [var.node_instance_type]
      min_size       = 1
      max_size       = 3
      desired_size   = 2
      capacity_type  = "SPOT" # cost-conscious for a portfolio/demo workload
    }
  }

  enable_cluster_creator_admin_permissions = true

  tags = local.tags
}

resource "aws_ecr_repository" "images" {
  name                 = "taskflow"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.tags
}
