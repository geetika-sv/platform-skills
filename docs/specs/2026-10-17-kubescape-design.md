# Kubescape Skills Design — v1.44.0

**Date:** 2026-10-17  
**Author:** Geetika Jain  
**Status:** Approved

---

## Overview

Add Kubescape (CNCF incubating) as two slash commands for v1.44.0:

- `/platform-skills:kubescape` — shift-left posture with the CLI: manifest, Helm, Kustomize and live-cluster scans against NSA-CISA, MITRE ATT&CK, CIS (vanilla, EKS, AKS, GKE) and SOC2; CI gating; exceptions; auto-fix; CEL admission policies; one-off image scans.
- `/platform-skills:kubescape-operator` — continuous in-cluster security with the Kubescape operator: install via Flux, relevancy-filtered vulnerability scanning, eBPF runtime threat detection, generated NetworkPolicies, in-cluster exceptions, Prometheus metrics, troubleshooting.

Scope is everything Kubescape does. Overlap with existing commands (Trivy, Falco, Kyverno, Checkov) is resolved by an ownership matrix enforced at both menus, not by leaving capabilities out.

---

## Verified facts (from source, not docs)

Every version, flag, value key and resource name below was read from the upstream source at the pinned version. Where the docs disagree, the source wins and the reference says so.

| Fact | Value | Source |
|---|---|---|
| CLI version | `v4.0.16` | `kubescape/kubescape` releases |
| Operator chart | `kubescape-operator` `1.40.4`, `kubeVersion: >=1.28.0-0` | `kubescape/helm-charts` tag `kubescape-operator-1.40.4` |
| Helm repo | `https://kubescape.github.io/helm-charts/` (no OCI registry published) | helm-charts README |
| Release signing | `checksums.sha256` + `.sig` + `.pem`, keyless; identity `https://github.com/kubescape/kubescape/.github/workflows/02-release.yaml@refs/tags/v4.0.16`, issuer `https://token.actions.githubusercontent.com` | certificate SAN of the v4.0.16 release |
| GitHub Action | `kubescape/github-action` latest release `v3.0.21` (2024-11) is a Docker action built `FROM quay.io/kubescape/kubescape-cli:v3.0.21`; README recommends `@main` and `tj-actions/changed-files` | action repo at tag `v3.0.21` |
| Gate flags | `--compliance-threshold` (float, framework/control/workload/`--view resource|control`), `--severity-threshold`; `--fail-threshold` no longer exists | `cmd/scan/scan.go` @ v4.0.16 |
| New in v4 | `--baseline`, `--baseline-fail-on-new`, `--kube-contexts`, `--fleet-report`, `kubescape diff`, `kubescape operator remediate` | `cmd/` @ v4.0.16 |
| Framework names | `NSA`, `MITRE`, `SOC2`, `cis-v1.12.0`, `cis-v1.10.0`, `cis-eks-t1.8.0`, `cis-aks-t1.8.0`, `cis-gke-v1.9.0`, `security`, `ArmoBest`, `DevOpsBest`, `WorkloadScan`, `AllControls` (CLI matching is case-insensitive) | `regolibrary` `frameworks/*.json` `name` field |
| Exceptions file | `postureExceptionPolicy`, `actions: [alertOnly]`, `resources[].designatorType: Attributes`, `posturePolicies[]` with `controlID`/`frameworkName` | kubescape.io accepting-risk |
| In-cluster exceptions | `SecurityException` (ns, `se`) and `ClusterSecurityException` (`cse`), `kubescape.io/v1beta1`; need `capabilities.riskAcceptance: enable` (default `disable`) | chart CRDs + values |
| Runtime rules | `Rules` (`kubescape.io/v1`), `RuntimeRuleAlertBinding`; default rules need `alertCRD.installDefault: true`; detection needs `capabilities.runtimeDetection: enable` (default `disable`) | chart CRDs + values, runtime docs |
| Exporters | `nodeAgent.config.{alertManagerExporterUrls,syslogExporterURL,httpExporterConfig.url,stdoutExporter}` | chart values |
| Profiles | storage `v0.0.331` (shipped in chart 1.40.4) serves `containerprofiles`; `applicationprofiles` and `networkneighborhoods` are deleted as deprecated, although the runtime and netpol docs still name them | `pkg/registry/file/cleanup.go` @ storage v0.0.331 |
| Generated policies | `generatednetworkpolicies` in `spdx.softwarecomposition.kubescape.io/v1beta1`, named `<kind>-<name>`; never applied automatically | storage register + netpol docs |
| Metrics | `kubescape_controls_total_{cluster,namespace,workload}_{critical,high,medium,low,unknown}`, `kubescape_vulnerabilities_{total,relevant}_*`; needs `capabilities.prometheusExporter: enable` | `prometheus-exporter/metrics/metrics.go` |

---

## Architecture

| Artifact | Purpose |
|---|---|
| `skills/kubescape/SKILL.md` | CLI command — modes `scan`, `cluster`, `ci`, `exceptions`, `fix`, `vap`, `image`, wizard |
| `skills/kubescape-operator/SKILL.md` | Operator command — modes `install`, `vulns`, `runtime`, `netpol`, `exceptions`, `metrics`, `debug` |
| `references/kubescape.md` | CLI deep dive: install and verify, frameworks, scan targets, gates, baseline, exceptions, controls-config, fix, VAP, image, CI, troubleshooting |
| `references/kubescape-operator.md` | Operator deep dive: capability matrix, Flux install, vulns and relevancy, runtime detection, netpol, exceptions CRDs, metrics, troubleshooting, upgrade and rollback |
| `examples/kubescape/` | CI workflow, exceptions file, failing and fixed manifests, offline validator |
| `examples/kubescape-operator/` | Flux namespace, HelmRepository, HelmRelease; SecurityException; RuntimeRuleAlertBinding; PrometheusRule; offline validator |
| `plugin-evals/kubescape-trigger/` | Trigger check: a framework-posture request must load `kubescape`, not `trivy` or `kyverno` |
| Doc wiring | Every file in CONTRIBUTING "Adding a New Domain" §3–§6, plus plugin.json, marketplace.json, INSTALLATION, CHANGELOG, website sidebars, test arrays |

---

## Ownership boundary

| Concern | Default owner | Kubescape instead when |
|---|---|---|
| K8s posture against NSA/MITRE/CIS/SOC2 | **kubescape** | — |
| Terraform misconfiguration | checkov | never |
| Image CVE gate in CI | trivy | the team already standardised on Grype |
| CVEs in running workloads | trivy (Trivy Operator) **or** kubescape-operator — one per cluster | relevancy matters (only CVEs in loaded packages) |
| Admission enforcement | kyverno | no Kyverno and Kubernetes ≥ 1.30 → `kubescape vap` |
| Runtime threats | runtime-security (Falco) | learned-profile anomaly detection is wanted; avoid two eBPF agents on the same nodes |
| NetworkPolicy authoring | kubernetes | generated policies as a reviewed starting draft |
| SOC 2 controls in Terraform | compliance | the SOC2 framework for the cluster side |

Existing skills that gain a pointer row: `trivy`, `runtime-security`, `kyverno`, `preflight`, `compliance`.

---

## CI design decision

Do not use `kubescape/github-action`. It pins CLI v3.0.21 inside a Docker image and its documented usage (`@main`, `tj-actions/changed-files`) contradicts the repo's SHA-pinning rules. The example workflow instead:

1. Downloads `kubescape_4.0.16_linux_amd64.tar.gz`, `checksums.sha256`, `.sig`, `.pem` from the release.
2. `cosign verify-blob` the checksums file against the release workflow identity and the GitHub OIDC issuer.
3. `sha256sum --check --ignore-missing` the tarball.
4. Scans with `--format sarif`, uploads with `github/codeql-action/upload-sarif` (SHA-pinned), and gates with `--compliance-threshold` and `--severity-threshold` in a separate step so the SARIF uploads even when the gate fails.
5. Uses `permissions: {contents: read, security-events: write}` and `persist-credentials: false`.

---

## Safety rules (both skills)

- `kubescape fix` runs with `--dry-run` first; cluster fixes are reviewed and committed to Git, never piped to `kubectl apply` on production.
- VAP bindings and Kyverno-style rollouts start at `Audit`/`Warn`, never `Deny` on first deploy.
- Generated NetworkPolicies go to Git and are applied by the GitOps reconciler after review.
- Every exception carries a reason and, in-cluster, an `expiresAt`.
- Runtime detection is introduced on one node pool first; learning period is explicit.
- Every operator change states blast radius, verification and rollback (`flux suspend`, `helm rollback`).

---

## Verification

- Download CLI v4.0.16 to the scratchpad, verify sha256, and run every CLI command in `references/kubescape.md` against `examples/kubescape/` (`list frameworks`, `scan`, `scan framework`, `--exceptions`, `--baseline`, `fix --dry-run`, `vap deploy-library`).
- No cluster is available: operator examples are validated against the chart 1.40.4 CRD schemas and YAML parsing only, and labelled `Status: Beta`.
- Run every script in CONTRIBUTING §7.

---

## Release

Branch `feat/kubescape` on the fork `geetika-sv/platform-skills`, PR to `nitinjain999/platform-skills` titled `feat(kubescape): add /platform-skills:kubescape and kubescape-operator — v1.44.0`. The maintainer merges, tags `v1.44.0` (which triggers `release.yml`), and repins `marketplace.json` `source.sha` in the follow-up PR, as for 1.41.0–1.43.0.
