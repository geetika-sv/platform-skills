#!/usr/bin/env bash
# Offline validator for examples/kubescape-operator/
# Run from anywhere: bash examples/kubescape-operator/kubescape-operator-validate.sh
# Requires: bash, python3 with PyYAML. When helm is on PATH it also renders the
# chart with the HelmRelease values and checks the result.
# Manifests are schema-checked by the kubeconform step in validate.yml.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DIR="$ROOT_DIR/examples/kubescape-operator"

ERRORS=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; ERRORS=$((ERRORS + 1)); }

FILES=(README.md flux/kustomization.yaml flux/namespace.yaml flux/helmrepository.yaml
       flux/helmrelease.yaml security-exception.yaml runtime-rule-binding.yaml prometheusrule.yaml)

echo ""
echo "=== Kubescape operator example structure ==="
for f in "${FILES[@]}"; do
  if [ -f "$DIR/$f" ]; then pass "$f exists"; else fail "$f missing"; fi
done
if grep -qE '^Status: (Stable|Beta|Draft|Experimental)' "$DIR/README.md" 2>/dev/null; then
  pass "README.md has a Status: line"
else
  fail "README.md needs a 'Status:' line near the top"
fi

echo ""
echo "=== Manifests parse ==="
for f in "${FILES[@]}"; do
  case "$f" in *.yaml) ;; *) continue ;; esac
  [ -f "$DIR/$f" ] || continue
  if python3 -I -c 'import sys, yaml; list(yaml.safe_load_all(open(sys.argv[1])))' "$DIR/$f" 2>/dev/null; then
    pass "$f is valid YAML"
  else
    fail "$f is invalid YAML"
  fi
done

echo ""
echo "=== HelmRelease pins and capabilities ==="
if python3 -I - "$DIR/flux/helmrelease.yaml" "$DIR/flux/helmrepository.yaml" <<'PY'
import sys, yaml
hr = yaml.safe_load(open(sys.argv[1])); repo = yaml.safe_load(open(sys.argv[2]))
errors = []
chart = hr["spec"]["chart"]["spec"]
if chart.get("chart") != "kubescape-operator": errors.append("chart must be kubescape-operator")
v = str(chart.get("version", ""))
if not v or any(c in v for c in "*^~<>x ") : errors.append(f"chart version must be an exact pin, got {v!r}")
if repo["spec"].get("url") != "https://kubescape.github.io/helm-charts/": errors.append("HelmRepository url must be https://kubescape.github.io/helm-charts/")
vals = hr["spec"].get("values", {})
if not vals.get("clusterName") or vals.get("clusterName") == "cluster": errors.append("set values.clusterName (the chart default 'cluster' makes every cluster look the same)")
caps = vals.get("capabilities", {})
# Mutating or self-upgrading capabilities stay off: GitOps owns upgrades, and
# remediation grants cluster-wide patch on nodes.
for k in ("remediation", "autoUpgrading", "manageWorkloads"):
    if caps.get(k, "disable") != "disable": errors.append(f"capabilities.{k} must stay disable")
for k in ("riskAcceptance", "runtimeDetection", "prometheusExporter", "continuousScan"):
    if caps.get(k) != "enable": errors.append(f"capabilities.{k} must be enable in this example")
if vals.get("alertCRD", {}).get("installDefault") is not True: errors.append("alertCRD.installDefault must be true (installs the default-rules Rules object)")
# Chart 1.40.4 bundles scanner v4.0.13, whose "all" framework scans (every
# scheduled and operator-triggered scan) fail with "framework 'C-0042' not found";
# fixed in v4.0.14 (kubescape#3768). Require an explicit scanner tag >= v4.0.14.
tag = str(vals.get("kubescape", {}).get("image", {}).get("tag", ""))
try:
    parts = tuple(int(x) for x in tag.lstrip("v").split("."))
except ValueError:
    parts = ()
if len(parts) != 3 or parts < (4, 0, 14): errors.append(f"values.kubescape.image.tag must pin the scanner to >= v4.0.14 (got {tag!r})")
if hr["spec"].get("install", {}).get("crds") not in ("Create", "CreateReplace"): errors.append("install.crds must be Create or CreateReplace")
if hr["spec"].get("upgrade", {}).get("crds") != "CreateReplace": errors.append("upgrade.crds must be CreateReplace so chart CRD changes land")
for e in errors: print("    -", e)
sys.exit(1 if errors else 0)
PY
then
  pass "HelmRelease pins the chart, names the cluster and keeps mutating capabilities off"
else
  fail "HelmRelease checks failed (see above)"
fi

echo ""
echo "=== No deprecated profile resources ==="
# storage v0.0.331 (chart 1.40.4) deletes applicationprofiles and
# networkneighborhoods; containerprofiles replaced them.
if grep -rnE 'applicationprofiles?|networkneighborhoods?|ApplicationProfile|NetworkNeighborhood' \
     "$DIR" --include='*.yaml' --include='*.sh' | grep -v 'kubescape-operator-validate.sh' >/dev/null; then
  fail "examples reference applicationprofiles/networkneighborhoods (removed); use containerprofiles"
else
  pass "no references to removed profile resources"
fi

echo ""
echo "=== SecurityException and runtime binding ==="
if python3 -I - "$DIR/security-exception.yaml" "$DIR/runtime-rule-binding.yaml" <<'PY'
import sys, yaml, datetime
errors = []
for doc in yaml.safe_load_all(open(sys.argv[1])):
    if not doc: continue
    name = doc["metadata"]["name"]; spec = doc.get("spec", {})
    if doc.get("apiVersion") != "kubescape.io/v1beta1" or doc.get("kind") not in ("SecurityException", "ClusterSecurityException"):
        errors.append(f"{name}: must be kubescape.io/v1beta1 SecurityException or ClusterSecurityException")
    for k in ("reason", "author", "expiresAt"):
        if not spec.get(k): errors.append(f"{name}: spec.{k} is required by this example's policy")
    try:
        datetime.datetime.fromisoformat(str(spec.get("expiresAt", "")).replace("Z", "+00:00"))
    except ValueError:
        errors.append(f"{name}: expiresAt must be RFC 3339")
    if not (spec.get("posture") or spec.get("vulnerabilities")): errors.append(f"{name}: needs posture or vulnerabilities")
    for p in spec.get("posture", []):
        if p.get("action") not in ("ignore", "alert_only"): errors.append(f"{name}: posture action must be ignore or alert_only")
for doc in yaml.safe_load_all(open(sys.argv[2])):
    if not doc: continue
    if doc.get("kind") != "RuntimeRuleAlertBinding": errors.append("runtime-rule-binding.yaml must be a RuntimeRuleAlertBinding")
    if not doc.get("spec", {}).get("rules"): errors.append("RuntimeRuleAlertBinding needs spec.rules")
for e in errors: print("    -", e)
sys.exit(1 if errors else 0)
PY
then
  pass "SecurityException carries reason, author, expiresAt; binding lists rules"
else
  fail "SecurityException or RuntimeRuleAlertBinding checks failed (see above)"
fi

echo ""
echo "=== PrometheusRule uses exported metric names ==="
for m in kubescape_controls_total_cluster_critical kubescape_controls_total_cluster_high kubescape_vulnerabilities_relevant_cluster_critical; do
  if grep -q "$m" "$DIR/prometheusrule.yaml" 2>/dev/null; then pass "prometheusrule.yaml uses $m"; else fail "prometheusrule.yaml should alert on $m"; fi
done

# node-agent v0.3.219 (Config.SkipNamespace) never traces pods in
# excludeNamespaces, so a binding for an excluded namespace can never fire.
# A namespace given its own binding must also be taken out of the chart's
# all-rules-all-pods binding (a post-renderer patch), or both bindings apply.
if python3 -I - "$DIR/runtime-rule-binding.yaml" "$DIR/flux/helmrelease.yaml" <<'PY'
import sys, yaml
binding = yaml.safe_load(open(sys.argv[1])); hr = yaml.safe_load(open(sys.argv[2]))
vals = hr["spec"].get("values", {})
excluded = {n.strip() for n in str(vals.get("excludeNamespaces", "")).split(",") if n.strip()}
included = {n.strip() for n in str(vals.get("includeNamespaces", "")).split(",") if n.strip()}
sel = binding["spec"].get("namespaceSelector", {})
targets = set()
for e in sel.get("matchExpressions", []):
    if e.get("key") == "kubernetes.io/metadata.name" and e.get("operator") == "In":
        targets |= set(e.get("values", []))
targets |= {v for k, v in (sel.get("matchLabels") or {}).items() if k == "kubernetes.io/metadata.name"}
errors = []
if not targets: errors.append("binding must select namespaces by kubernetes.io/metadata.name so this check can verify them")
for ns in sorted(targets):
    if ns in excluded: errors.append(f"{ns} is in excludeNamespaces: node-agent never traces it, the binding cannot fire")
    if included and ns not in included: errors.append(f"{ns} is not in includeNamespaces: node-agent never traces it")
patched = set()
for pr in hr["spec"].get("postRenderers", []) or []:
    for p in (pr.get("kustomize") or {}).get("patches", []) or []:
        t = p.get("target", {})
        if t.get("kind") == "RuntimeRuleAlertBinding" and t.get("name") == "all-rules-all-pods":
            for op in yaml.safe_load(p.get("patch", "[]")) or []:
                if op.get("op") == "add" and str(op.get("path", "")).endswith("/values/-"):
                    patched.add(op.get("value"))
for ns in sorted(targets - patched):
    errors.append(f"{ns} is still covered by all-rules-all-pods; add a postRenderers patch that adds it to that binding's NotIn list")
if included: errors.append("this example's post-renderer patch assumes excludeNamespaces (the default binding uses NotIn); with includeNamespaces it uses In")
for e in errors: print("    -", e)
sys.exit(1 if errors else 0)
PY
then
  pass "runtime binding targets traced namespaces, removed from the default binding"
else
  fail "runtime binding would never fire or would double up with all-rules-all-pods (see above)"
fi

# prometheus-exporter v0.2.23 registers the cluster gauges in init(): a running
# exporter always serves them (0, or the last value), so absent() only means
# "exporter not scraped". It must not be sold as scan-failure detection.
if python3 -I - "$DIR/prometheusrule.yaml" <<'PY'
import sys, yaml
doc = yaml.safe_load(open(sys.argv[1]))
bad = [r["alert"] for g in doc["spec"]["groups"] for r in g["rules"]
       if "absent(" in str(r.get("expr", "")) and "scan" in (" ".join(str(v) for v in (r.get("annotations") or {}).values()) + r["alert"]).lower()]
for b in bad: print("    -", b)
sys.exit(1 if bad else 0)
PY
then
  pass "absent() alerts claim only a missing exporter, not failing scans"
else
  fail "an absent() alert claims to detect failing scans; the exporter's gauges exist even when every scan fails"
fi

echo ""
echo "=== Chart renders with these values (helm) ==="
if [ ! -f "$DIR/flux/helmrelease.yaml" ]; then
  echo "  SKIP: flux/helmrelease.yaml missing (reported above)"
elif command -v helm >/dev/null 2>&1; then
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  ver="$(python3 -I -c 'import sys,yaml;print(yaml.safe_load(open(sys.argv[1]))["spec"]["chart"]["spec"]["version"])' "$DIR/flux/helmrelease.yaml")"
  python3 -I -c 'import sys,yaml;yaml.safe_dump(yaml.safe_load(open(sys.argv[1]))["spec"]["values"],open(sys.argv[2],"w"))' "$DIR/flux/helmrelease.yaml" "$tmp/values.yaml"
  if helm template kubescape kubescape-operator --repo https://kubescape.github.io/helm-charts/ \
       --version "$ver" --namespace kubescape -f "$tmp/values.yaml" > "$tmp/out.yaml" 2>"$tmp/err"; then
    pass "helm template kubescape-operator $ver renders"
    if grep -q 'name: node-agent' "$tmp/out.yaml"; then pass "node-agent DaemonSet rendered"; else fail "node-agent not rendered"; fi
    if grep -q 'name: prometheus-exporter' "$tmp/out.yaml"; then pass "prometheus-exporter rendered"; else fail "prometheus-exporter not rendered"; fi
  else
    fail "helm template failed: $(head -3 "$tmp/err")"
  fi
else
  echo "  SKIP: helm not on PATH; chart not rendered"
fi

echo ""
if [ "$ERRORS" -gt 0 ]; then
  echo "FAIL: $ERRORS kubescape-operator example error(s)"
  exit 1
fi
echo "PASS: kubescape-operator example checks passed"
