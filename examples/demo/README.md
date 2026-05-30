# Demo Gallery

Status: Stable

Short before/after demos that show platform-skills catching production risks in realistic platform engineering changes. Each demo includes a risky input, a safer output, a copy-paste prompt, and a GIF/tape recording for launch posts, docs, and internal enablement.

## Demos

| Demo | Problem | Risky input | Safer output | Recording |
|---|---|---|---|---|
| [Kubernetes production review](kubernetes-prod-review/) | Deployment missing production guardrails | [bad.yaml](kubernetes-prod-review/bad.yaml) | [fixed.yaml](kubernetes-prod-review/fixed.yaml) | [demo.gif](kubernetes-prod-review/demo.gif) |
| [Terraform IAM risk](terraform-iam-risk/) | Wildcard IAM permissions hidden in Terraform | [bad.tf](terraform-iam-risk/bad.tf) | [fixed.tf](terraform-iam-risk/fixed.tf) | [demo.gif](terraform-iam-risk/demo.gif) |
| [Flux stuck release](flux-stuck-release/) | HelmRelease can drift or break silently | [bad.yaml](flux-stuck-release/bad.yaml) | [fixed.yaml](flux-stuck-release/fixed.yaml) | [demo.gif](flux-stuck-release/demo.gif) |
| [GitHub Actions supply chain](github-actions-supply-chain/) | Mutable actions and weak permissions | [bad.yml](github-actions-supply-chain/bad.yml) | [fixed.yml](github-actions-supply-chain/fixed.yml) | [demo.gif](github-actions-supply-chain/demo.gif) |
| [OPA policy review](opa-policy-review/) | Rego policy missing modern syntax and tests | [bad.rego](opa-policy-review/bad.rego) | [fixed.rego](opa-policy-review/fixed.rego) | [demo.gif](opa-policy-review/demo.gif) |
| [PR triage](pr-triage/) | Review comments need classification and safe fixes | [deployment.yaml](pr-triage/deployment.yaml) | [deployment-fixed.yaml](pr-triage/deployment-fixed.yaml) | [demo.gif](pr-triage/demo.gif) |

## Try One

```text
Use $platform-skills to review this change for production readiness. Focus on blast radius, validation, rollback, and security defaults.
```

## Maintenance

Regenerate GIFs from the committed tape files:

```bash
./scripts/gen-demo-gifs.sh
```

Keep each demo small enough to inspect in GitHub, and prefer fixing the source `demo.tape` before replacing binary GIF output.
