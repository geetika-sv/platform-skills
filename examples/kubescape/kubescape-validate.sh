#!/usr/bin/env bash
# Offline validator for examples/kubescape/
# Run from anywhere: bash examples/kubescape/kubescape-validate.sh
# Requires: bash, python3 with PyYAML. When the kubescape CLI is on PATH it also
# proves the gate: the hardened manifests pass and the insecure one fails.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DIR="$ROOT_DIR/examples/kubescape"
WORKFLOW="$DIR/workflows/kubescape.yml"

ERRORS=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; ERRORS=$((ERRORS + 1)); }

echo ""
echo "=== Kubescape example structure ==="
for f in README.md exceptions.json workflows/kubescape.yml \
         manifests/insecure/deployment.yaml \
         manifests/hardened/deployment.yaml manifests/hardened/networkpolicy.yaml; do
  if [ -f "$DIR/$f" ]; then pass "$f exists"; else fail "$f missing"; fi
done

if grep -qE '^Status: (Stable|Beta|Draft|Experimental)' "$DIR/README.md" 2>/dev/null; then
  pass "README.md has a Status: line"
else
  fail "README.md needs a 'Status:' line near the top"
fi

echo ""
echo "=== exceptions.json follows the postureExceptionPolicy schema ==="
# Each entry needs a reason-bearing name, the fixed policyType, one action and
# at least one resource and one policy. Kubescape (opa-utils v0.0.315) treats the
# two actions differently: "disable" removes the finding from the score and the
# gates; "alertOnly" keeps it failing. A disable entry is an accepted risk, so
# its name must carry an until-YYYY-MM-DD review date. Expiry itself is enforced
# by the CI workflow, not here, so this repository's CI never expires.
if python3 -I - "$DIR/exceptions.json" <<'PY'
import json, re, sys
entries = json.load(open(sys.argv[1]))
assert isinstance(entries, list) and entries, "exceptions.json must be a non-empty list"
for e in entries:
    name = e.get("name", "<unnamed>")
    assert e.get("name"), "every exception needs a name"
    assert e.get("policyType") == "postureExceptionPolicy", f"{name}: policyType must be postureExceptionPolicy"
    assert e.get("actions") in (["disable"], ["alertOnly"]), f"{name}: actions must be [disable] or [alertOnly]"
    if e["actions"] == ["disable"]:
        assert re.search(r"until-\d{4}-\d{2}-\d{2}$", name), f"{name}: a disable exception needs an until-YYYY-MM-DD suffix"
    res = e.get("resources") or []
    assert res and all(r.get("designatorType") == "Attributes" and r.get("attributes") for r in res), \
        f"{name}: resources need designatorType Attributes and attributes"
    pols = e.get("posturePolicies") or []
    assert pols and all(p.get("controlID") or p.get("frameworkName") for p in pols), \
        f"{name}: posturePolicies need controlID or frameworkName"
    assert not any("controlName" in p for p in pols), f"{name}: controlName is deprecated; use controlID"
PY
then
  pass "exceptions.json entries are well formed"
else
  fail "exceptions.json is malformed (see the assertion above)"
fi

echo ""
echo "=== Manifests and workflow parse ==="
for f in manifests/insecure/deployment.yaml manifests/hardened/deployment.yaml \
         manifests/hardened/networkpolicy.yaml workflows/kubescape.yml; do
  [ -f "$DIR/$f" ] || continue
  if python3 -I -c 'import sys, yaml; list(yaml.safe_load_all(open(sys.argv[1])))' "$DIR/$f" 2>/dev/null; then
    pass "$f is valid YAML"
  else
    fail "$f is invalid YAML"
  fi
done

echo ""
echo "=== CI workflow supply-chain rules ==="
if [ -f "$WORKFLOW" ]; then
  # kubescape/github-action's latest release bundles CLI v3.0.21 and its README
  # recommends @main plus tj-actions/changed-files; the workflow installs a
  # signature-verified CLI instead.
  if grep -qE 'uses:[[:space:]]*kubescape/github-action' "$WORKFLOW"; then
    fail "workflow uses kubescape/github-action (stale CLI); install the pinned CLI instead"
  else
    pass "workflow does not use kubescape/github-action"
  fi
  if grep -qE 'uses:[[:space:]]*tj-actions/' "$WORKFLOW"; then
    fail "workflow uses tj-actions/* (compromised in March 2025)"
  else
    pass "workflow does not use tj-actions/*"
  fi
  unpinned="$(grep -nE '^[[:space:]]*-?[[:space:]]*uses:' "$WORKFLOW" | grep -vE '@[0-9a-f]{40}' || true)"
  if [ -z "$unpinned" ]; then
    pass "every uses: is pinned to a full commit SHA"
  else
    fail "unpinned uses: $unpinned"
  fi
  version="$(sed -nE 's/^[[:space:]]*KUBESCAPE_VERSION:[[:space:]]*"?([0-9]+\.[0-9]+\.[0-9]+)"?.*/\1/p' "$WORKFLOW" | head -1)"
  if [ -n "$version" ]; then
    pass "KUBESCAPE_VERSION pinned to $version"
  else
    fail "KUBESCAPE_VERSION must be pinned to an exact X.Y.Z"
  fi
  if grep -q 'cosign verify-blob' "$WORKFLOW" \
     && grep -q 'certificate-identity "https://github.com/kubescape/kubescape/.github/workflows/02-release.yaml@refs/tags/v${KUBESCAPE_VERSION}"' "$WORKFLOW" \
     && grep -q 'certificate-oidc-issuer "https://token.actions.githubusercontent.com"' "$WORKFLOW"; then
    pass "CLI download is verified with cosign against the release workflow identity"
  else
    fail "workflow must cosign verify-blob checksums.sha256 against the 02-release.yaml identity and GitHub OIDC issuer"
  fi
  if grep -qE 'sha256sum (--check|-c)' "$WORKFLOW"; then
    pass "tarball checked against the verified checksums"
  else
    fail "workflow must sha256sum --check the tarball against checksums.sha256"
  fi
  if grep -q 'persist-credentials: false' "$WORKFLOW"; then
    pass "checkout does not persist credentials"
  else
    fail "actions/checkout must set persist-credentials: false"
  fi
fi

echo ""
echo "=== Gate behaviour (kubescape CLI) ==="
if command -v kubescape >/dev/null 2>&1; then
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  if kubescape scan framework nsa "$DIR/manifests/hardened" --severity-threshold medium \
       --format json --output "$tmp/hardened.json" >/dev/null 2>&1; then
    pass "hardened manifests pass NSA at --severity-threshold medium"
  else
    fail "hardened manifests should pass NSA at --severity-threshold medium"
  fi
  if kubescape scan framework nsa "$DIR/manifests/insecure" --severity-threshold medium \
       --format json --output "$tmp/insecure.json" >/dev/null 2>&1; then
    fail "insecure manifest should fail NSA at --severity-threshold medium"
  else
    pass "insecure manifest fails NSA at --severity-threshold medium"
  fi
else
  echo "  SKIP: kubescape not on PATH; gate behaviour not exercised"
fi

echo ""
if [ "$ERRORS" -gt 0 ]; then
  echo "FAIL: $ERRORS kubescape example error(s)"
  exit 1
fi
echo "PASS: kubescape example checks passed"
