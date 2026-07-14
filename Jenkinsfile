// Push-based CI/CD for the AWS/EKS side of this project — the deliberate
// counterpart to the GitOps/ArgoCD pattern used on GCP (see gitops/ and
// .github/workflows/ci.yml). Jenkins builds, pushes to ECR, and applies
// directly to the cluster itself, rather than a controller pulling from git.
pipeline {
    agent any

    environment {
        AWS_REGION   = 'us-east-1'
        CLUSTER_NAME = 'multicloud-gitops-cluster'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Lint & test') {
            steps {
                sh '''
                    python3 -m venv .venv
                    . .venv/bin/activate
                    pip install -q -r app/api/requirements-dev.txt
                    ruff check app/api
                    pytest -q
                '''
            }
        }

        stage('Build image') {
            steps {
                script {
                    env.IMAGE_TAG = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                }
                sh 'docker build -t taskflow-api:${IMAGE_TAG} app/api'
            }
        }

        stage('Push to ECR') {
            steps {
                sh '''
                    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
                    ECR_REPO="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/taskflow"

                    aws ecr get-login-password --region "${AWS_REGION}" \
                        | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

                    docker tag taskflow-api:${IMAGE_TAG} "${ECR_REPO}:${IMAGE_TAG}"
                    docker push "${ECR_REPO}:${IMAGE_TAG}"

                    echo "${ECR_REPO}" > ecr_repo.txt
                '''
            }
        }

        stage('Deploy to EKS') {
            steps {
                sh '''
                    aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${AWS_REGION}"

                    # metrics-server isn't bundled on EKS (unlike GKE Autopilot) but the
                    # HPA in deploy/aws/k8s needs it; idempotent, safe to re-apply.
                    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

                    ECR_REPO=$(cat ecr_repo.txt)
                    cd deploy/aws/k8s
                    sed -i "s#newName:.*#newName: ${ECR_REPO}#" kustomization.yaml
                    sed -i "s/newTag:.*/newTag: ${IMAGE_TAG}/" kustomization.yaml
                    kubectl apply -k .
                    kubectl rollout status deployment/taskflow-api --timeout=120s
                '''
            }
        }
    }
}
