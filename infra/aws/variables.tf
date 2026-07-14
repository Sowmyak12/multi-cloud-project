variable "region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name, used for FinOps tagging"
  type        = string
  default     = "portfolio"
}

variable "cost_center" {
  description = "Cost center tag for FinOps governance"
  type        = string
  default     = "personal-portfolio"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "multicloud-gitops-cluster"
}

variable "node_instance_type" {
  description = "EC2 instance type for the EKS managed node group (kept small/cheap intentionally)"
  type        = string
  default     = "t3.small"
}

variable "admin_cidr" {
  description = "Your IP in CIDR form (e.g. 1.2.3.4/32), used to restrict access to the Jenkins UI. Find yours at whatismyip.com"
  type        = string
}

variable "jenkins_instance_type" {
  description = "EC2 instance type for the Jenkins controller. t3.micro is the safe default: it's the only type Free Tier / brand-new AWS accounts are allowed to launch (anything else gets InvalidParameterCombination). Bump it once your account ages out of that restriction, if Jenkins feels memory-starved."
  type        = string
  default     = "t3.micro"
}
