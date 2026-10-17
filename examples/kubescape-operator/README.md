# Kubescape Operator Example

Status: Beta

Continuous Kubernetes security with the Kubescape operator, installed by Flux: posture scans on every change, image vulnerabilities, runtime threat detection, generated NetworkPolicies, in-cluster exceptions with an expiry, and Prometheus alerts.

Chart `kubescape-operator` 1.40.4 with the scanner pinned to v4.0.16, Flux v2.9, Kubernetes ≥ 1.28.

| File | What it does |
|---|---|
| `flux/namespace.yaml` | `kubescape` namespace, Pod Security level `privileged` (node-agent is a privileged eBPF DaemonSet) |
| `flux/helmrepository.yaml` | `https://kubescape.github.io/helm-charts/` (no OCI registry is published) |
| `flux/helmrelease.yaml` | Pinned chart, named cluster, every capability set explicitly with the reason, scanner image override, mutating capabilities off |
| `flux/kustomization.yaml` | The three above, for `kubectl apply -k` or a Flux `Kustomization` |
| `security-exception.yaml` | `SecurityException` with reason, author and `expiresAt`, suppressing one control on one Deployment |
| `runtime-rule-binding.yaml` | `RuntimeRuleAlertBinding` adding high-signal runtime rules to `kube-system`, which the default binding excludes |
| `prometheusrule.yaml` | Five alerts on the exporter's metrics, including a fallback for clusters without relevancy and an alert when the exporter stops reporting |
| `kubescape-operator-validate.sh` | Offline checks; renders the chart with these values when `helm` is on PATH |

## Install

```bash
# Preflight: node-agent needs eBPF and fanotify permission events on every node
kubectl debug node/<node> --image=busybox:1.37 --profile=sysadmin -- \
  sh -c 'uname -r; zcat /proc/config.gz | grep -E "CONFIG_FANOTIFY_ACCESS_PERMISSIONS|CONFIG_DEBUG_INFO_BTF"'
# want: CONFIG_FANOTIFY_ACCESS_PERMISSIONS=y and CONFIG_DEBUG_INFO_BTF=y

kubectl apply -k examples/kubescape-operator/flux      # or commit it under your Flux path
kubectl -n kubescape wait helmrelease/kubescape --for=condition=Ready --timeout=10m
kubectl -n kubescape get pods
```

Then:

```bash
kubescape operator scan configurations                 # on-demand posture scan
kubectl get workloadconfigurationscansummaries -A      # results per workload
kubescape operator scan vulnerabilities --include-namespaces payments
kubectl get vulnerabilitymanifestsummaries -A
kubectl apply -f examples/kubescape-operator/security-exception.yaml
```

## What was verified, and where

Live on Kubernetes 1.36 (docker-desktop, arm64) through Flux: install, posture summaries per workload and namespace, on-demand configuration and vulnerability scans, `SecurityException` suppression (C-0237 moved to `passed (w/exceptions)` within 40 s, and the CLI honoured it on a cluster scan), the Prometheus exporter's metrics, server-side validation of the `RuntimeRuleAlertBinding`. The alerts were unit-tested with `promtool test rules`.

Not run live: anything that needs the node-agent (runtime detection, container profiles, relevancy, generated NetworkPolicies). Docker Desktop's kernel (7.0.14-linuxkit) is built without `CONFIG_FANOTIFY_ACCESS_PERMISSIONS`, so node-agent crash-loops there with `no container runtime can be monitored with fanotify`; the same applies to kind and minikube inside Docker Desktop. The docker-desktop run used this HelmRelease with the seven node-agent capabilities set to `disable` (see `references/kubescape-operator.md`, "Install profiles"). EKS, AKS and GKE node images ship the option.

## Two things that are not obvious

**The chart's bundled scanner is too old.** Chart 1.40.4 ships scanner v4.0.13, whose `all` framework scans fail with `framework 'C-0042' not found` against the current controls (fixed in v4.0.14, kubescape#3768). Every scheduled and operator-triggered scan uses `all`, so without the `kubescape.image.tag` override the operator installs cleanly and then produces no results. No metric shows it: the exporter keeps serving its gauges (0, or the last value), so watch the scanner's logs for `scanning failed` (`references/kubescape-operator.md`, Metrics).

**A node-agent that cannot start removes everything.** With Flux's default install wait, a node-agent that never becomes Ready fails the Helm install and Flux's remediation uninstalls the whole release, posture scanning included. Run the kernel preflight above before enabling the node-agent capabilities.

## Rollback

```bash
flux suspend helmrelease kubescape -n kubescape        # stop reconciling, keep what runs
git revert <commit> && flux resume helmrelease kubescape -n kubescape   # back to the previous values
kubectl delete -k examples/kubescape-operator/flux      # remove; CRDs stay (delete them explicitly if wanted)
```

## See also

- `/platform-skills:kubescape-operator` and `references/kubescape-operator.md`: full guide
- `/platform-skills:kubescape` and `examples/kubescape/`: CLI scans and the PR gate
- `/platform-skills:runtime-security` (Falco) · `/platform-skills:trivy` (Trivy Operator) · `/platform-skills:observability`
