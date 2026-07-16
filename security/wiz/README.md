# Wiz (CNAPP)

Wiz is a Cloud-Native Application Protection Platform: agentless cloud
security posture management (CSPM), vulnerability management, IaC scanning,
and cloud identity/entitlement analysis (CIEM), with an optional in-cluster
sensor for runtime visibility. It's become one of the standard tools
platform/security teams reach for, so this repo wires it into both places it
actually belongs — CI and the cluster — the same disciplined way everything
else here is built: real, correct configuration, honestly documented rather
than faked.

## Where it's wired in

**1. CI — IaC scanning** ([`.github/workflows/ci.yml`](../../.github/workflows/ci.yml),
`iac-scan` job): the `wizcli` CLI authenticates with a service account and
scans both Terraform stacks (`infra/gcp`, `infra/aws`) the same way `tfsec`
already does here — Wiz alongside a dedicated scanner, not instead of one,
which is how it's typically deployed in practice. The step is gated on
`secrets.WIZ_CLIENT_ID` being set, so this repo still builds and runs cleanly
for anyone without a Wiz tenant (which is everyone except an actual Wiz
customer — this includes anyone reviewing this repo).

**2. Cluster — the Sensor** ([`values.yaml`](values.yaml),
[`gitops/argocd/apps/optional/wiz-sensor.yaml`](../../gitops/argocd/apps/optional/wiz-sensor.yaml)):
Wiz's core scanning is agentless — it connects to a cloud account via
IAM role, the same pattern this repo already uses for GitHub Actions → GCP/AWS
auth. The Sensor is the *optional* add-on layered on top for
process/file/network-level runtime visibility inside pods. It's deployed via
Helm through ArgoCD, consistent with how Prometheus and Vault are deployed
elsewhere in this repo — except this one lives in
`gitops/argocd/apps/optional/`, deliberately outside the root app-of-apps'
auto-synced scope, since Wiz generates the chart repo URL and
client credentials per-tenant on its own connector setup page. There's
nothing public and stable to point at until you actually have a Wiz account.

## Activating it for real

1. Create a Wiz account/tenant (or use an employer-provided one).
2. In the Wiz console: **Security Graph → Connectors → add a Kubernetes
   cluster connector.** Wiz generates a chart repo URL, chart version, and a
   `clientId`/`clientSecret` scoped to that connector.
3. Fill those into [`gitops/argocd/apps/optional/wiz-sensor.yaml`](../../gitops/argocd/apps/optional/wiz-sensor.yaml)
   and store the real secret via a Kubernetes `Secret` (referenced, never
   committed) rather than inline in `values.yaml`.
4. Move (or symlink) `wiz-sensor.yaml` into `gitops/argocd/apps/children/` so
   the root app-of-apps picks it up — same mechanism as every other component
   here.
5. Add `WIZ_CLIENT_ID`/`WIZ_CLIENT_SECRET` as GitHub Actions secrets to turn
   on the CI IaC-scan step.

## What this is (and isn't) meant to show

This demonstrates the integration itself — how Wiz's agentless CSPM model,
its optional in-cluster sensor, and its CI-time IaC scanning actually fit
into a real GitOps pipeline, and where the tenant-specific pieces have to
plug in. It isn't a claim of production Wiz findings or dashboards from a
live tenant, since this portfolio project doesn't have one — same honesty
standard as the rest of this repo (see the main README's Phase 2 section for
other pieces documented-but-not-deployed the same way).
