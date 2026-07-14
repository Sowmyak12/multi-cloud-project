# AWS mirror (EKS) — Jenkins, not GitOps

Deliberately different from the GCP side: instead of ArgoCD pulling from git,
a Jenkins controller (also provisioned by this Terraform, see `jenkins.tf`)
builds the image, pushes it to ECR, and applies straight to the cluster via
`kubectl` — classic push-based CI/CD. Same app, same Kubernetes cluster
shape, intentionally different deployment pattern to show both.

Uses the community `terraform-aws-modules/vpc` and `terraform-aws-modules/eks`
modules (the standard, production-grade way to stand these up on AWS) rather
than hand-rolling VPC/EKS resources.

Jenkins runs on a single EC2 instance with no SSH key pair and no open port
22 — access is via AWS Systems Manager Session Manager instead, and its web
UI (port 8080) is locked to your own IP (`admin_cidr`). Its IAM role is
granted Kubernetes RBAC access to the EKS cluster via an EKS access entry
(`main.tf`), not the older `aws-auth` ConfigMap approach.

See [`docs/bootstrap-aws.md`](../../docs/bootstrap-aws.md) for the full,
copy-paste setup (CloudShell → `terraform apply` → unlock Jenkins → create
the pipeline).

Cost-conscious choices already baked in: a single NAT gateway instead of one
per AZ, SPOT capacity for the node group, a small default instance type for
both the node group and Jenkins itself, and the same `Environment`/
`CostCenter` tagging scheme as the GCP side for FinOps governance across both
clouds. EKS itself has a flat ~$0.10/hr control-plane fee regardless of
usage (unlike GKE Autopilot's pay-per-pod pricing) — `terraform destroy` when
you're done demoing.
