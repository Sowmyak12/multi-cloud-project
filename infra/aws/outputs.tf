output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "ecr_repository_url" {
  value = aws_ecr_repository.images.repository_url
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "jenkins_url" {
  value = "http://${aws_instance.jenkins.public_ip}:8080"
}

output "jenkins_instance_id" {
  description = "Use with: aws ssm start-session --target <id>  (no SSH key needed)"
  value       = aws_instance.jenkins.id
}
