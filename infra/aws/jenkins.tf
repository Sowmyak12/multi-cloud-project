# Jenkins on a single EC2 instance: the classic, push-based CI/CD counterpart
# to the GitOps/ArgoCD pattern used on the GCP side. Deliberately different
# tooling to demonstrate both patterns rather than repeating the same one
# twice.
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_iam_role" "jenkins" {
  name = "jenkins-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

# SSM Session Manager instead of SSH: no key pair to manage, no port 22 open.
resource "aws_iam_role_policy_attachment" "jenkins_ssm" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "jenkins_ecr" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

# Lets `aws eks update-kubeconfig` resolve the cluster; actual in-cluster
# permissions come from the access_entries block on the eks module in main.tf.
resource "aws_iam_role_policy" "jenkins_eks_describe" {
  name = "eks-describe"
  role = aws_iam_role.jenkins.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["eks:DescribeCluster"]
      Resource = module.eks.cluster_arn
    }]
  })
}

resource "aws_iam_instance_profile" "jenkins" {
  name = "jenkins-controller"
  role = aws_iam_role.jenkins.name
}

resource "aws_security_group" "jenkins" {
  name_prefix = "jenkins-"
  description = "Jenkins UI, restricted to admin_cidr"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Jenkins UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

resource "aws_instance" "jenkins" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = var.jenkins_instance_type
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.jenkins.id]
  iam_instance_profile   = aws_iam_instance_profile.jenkins.name

  associate_public_ip_address = true

  user_data                   = file("${path.module}/jenkins-user-data.sh")
  user_data_replace_on_change = true

  tags = merge(local.tags, { Name = "jenkins-controller" })
}
