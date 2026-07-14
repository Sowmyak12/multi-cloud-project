#!/bin/bash
set -euxo pipefail

# Java + Jenkins
dnf install -y java-17-amazon-corretto
curl -fsSL https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key -o /etc/pki/rpm-gpg/jenkins.io-2023.key
cat <<'REPO' > /etc/yum.repos.d/jenkins.repo
[jenkins]
name=Jenkins
baseurl=https://pkg.jenkins.io/redhat-stable
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/jenkins.io-2023.key
REPO
dnf install -y jenkins
systemctl enable jenkins

# Docker, so Jenkins can build/push images
dnf install -y docker
systemctl enable --now docker
usermod -aG docker jenkins

# kubectl
curl -fsSLO "https://s3.us-west-2.amazonaws.com/amazon-eks/1.30.0/2024-05-12/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/

# Helm
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# AWS CLI v2
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip -q awscliv2.zip
./aws/install
rm -rf awscliv2.zip aws

systemctl start jenkins
