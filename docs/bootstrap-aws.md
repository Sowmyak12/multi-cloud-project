# AWS + Jenkins bootstrap

Unlike the GCP side (where GitHub Actions runs `terraform apply` automatically),
this AWS stack is applied **once, manually, from AWS CloudShell** — there's no
CI automation triggering AWS infra changes, and Jenkins itself only handles
app deploys, not infrastructure. That's why this uses local Terraform state
instead of a remote S3 backend: only you ever run `apply`/`destroy` here, and
always from the same CloudShell session.

## 1. Get your IP

Jenkins' UI is locked down to your IP only. Find yours at
[whatismyip.com](https://www.whatismyip.com) and keep it handy as `x.x.x.x/32`.

## 2. Open AWS CloudShell

In the AWS Console, click the CloudShell icon (top nav bar). This already has
`aws`, `terraform`... actually it doesn't have Terraform pre-installed —
install it once per session:

```bash
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum install -y terraform
```

## 3. Configure and apply

```bash
git clone https://github.com/Sowmyak12/multi-cloud-project.git
cd multi-cloud-project/infra/aws
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`: set `admin_cidr` to your IP from step 1 (required,
no default — this is what keeps the Jenkins UI from being open to the
internet).

```bash
terraform init
terraform apply
```

Takes ~15 minutes (EKS control plane is the slow part). At the end, note the
`jenkins_url` and `jenkins_instance_id` outputs.

## 4. Unlock Jenkins

SSH isn't used here — the Jenkins instance only has an IAM role + SSM, no key
pair, no open port 22. Get a shell via Session Manager instead:

```bash
aws ssm start-session --target <jenkins_instance_id from step 3>
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Open the `jenkins_url` output in your browser, paste that password in, install
the suggested plugins, create your admin user.

## 5. Create the pipeline

New Item → Pipeline → name it `taskflow-aws-deploy` →
**Pipeline script from SCM** → Git → paste the repo URL
(`https://github.com/Sowmyak12/multi-cloud-project.git`) → Script Path:
`Jenkinsfile` → Save → **Build Now**.

Watch the console output: lint/test → build the image → push to ECR →
`kubectl apply` to EKS. First run also installs `metrics-server` (needed for
the HPA — EKS doesn't bundle it the way GKE Autopilot does).

## 6. Verify

```bash
kubectl get svc taskflow-api
```

Once `EXTERNAL-IP` populates (AWS Classic ELB, a couple minutes), hit
`http://<that-ip>/healthz` the same way as the GCP deployment.

## Cost / cleanup

EKS has a flat ~$0.10/hr control-plane fee regardless of usage (unlike GKE
Autopilot's pay-per-pod model), plus the SPOT worker nodes and the Jenkins
EC2 instance. When you're done demoing:

```bash
cd infra/aws
terraform destroy
```

Since local state lives only in that CloudShell session's `$HOME`, if you
come back later in a fresh CloudShell session, re-run steps 2–3 (`git clone`,
`terraform init`) first — CloudShell persists `$HOME` across sessions, so
your state file (and `terraform.tfvars`) should actually still be there.
