#!/usr/bin/env bash
# CI quality gates: JSON syntax, YAML syntax, shell script lint, stale versions.
# Run from the repository root: bash tests/validate-ci.sh
# Requires: bash, jq. shellcheck/yamllint used when available.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ERRORS=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; ERRORS=$((ERRORS + 1)); }

# ---------------------------------------------------------------------------
echo ""
echo "=== JSON syntax ==="

while IFS= read -r f; do
  if jq empty "$f" >/dev/null 2>&1; then
    pass "$f is valid JSON"
  else
    fail "$f is invalid JSON"
  fi
done < <(find . -name "*.json" \
  ! -path "./.git/*" \
  ! -path "./node_modules/*" \
  | sort)

# ---------------------------------------------------------------------------
echo ""
echo "=== YAML syntax ==="

if command -v yamllint >/dev/null 2>&1; then
  while IFS= read -r f; do
    # Skip template files that intentionally contain placeholder values
    if grep -q "YOUR_\|PLACEHOLDER\|<REPLACE" "$f" 2>/dev/null; then
      echo "  INFO: skipping template file $f"
      continue
    fi
    if yamllint -d "{extends: relaxed, rules: {line-length: {max: 200}}}" "$f" >/dev/null 2>&1; then
      pass "$f is valid YAML"
    else
      fail "$f has YAML issues — run: yamllint $f"
    fi
  done < <(find . \( -name "*.yaml" -o -name "*.yml" \) \
    ! -path "./.git/*" \
    ! -path "./node_modules/*" \
    ! -path "*/templates/*" \
    | sort)
else
  echo "  INFO: yamllint not found — skipping YAML lint (install: pip install yamllint)"
  # Fallback: check YAML files parse with python if available and PyYAML is installed
  if command -v python3 >/dev/null 2>&1 && python3 -c "import yaml" >/dev/null 2>&1; then
    while IFS= read -r f; do
      if grep -q "YOUR_\|PLACEHOLDER\|<REPLACE" "$f" 2>/dev/null; then
        continue
      fi
      if python3 -c "import sys, yaml; list(yaml.safe_load_all(open(sys.argv[1])))" "$f" >/dev/null 2>&1; then
        pass "$f parses as valid YAML"
      else
        fail "$f is invalid YAML"
      fi
    done < <(find . \( -name "*.yaml" -o -name "*.yml" \) \
      ! -path "./.git/*" \
      ! -path "./node_modules/*" \
      ! -path "*/templates/*" \
      | sort)
  else
    echo "  INFO: python3/PyYAML not found — YAML validation skipped entirely"
  fi
fi

# ---------------------------------------------------------------------------
echo ""
echo "=== Shell script lint ==="

if command -v shellcheck >/dev/null 2>&1; then
  while IFS= read -r script; do
    if shellcheck --severity=warning "$script" >/dev/null 2>&1; then
      pass "shellcheck: $script"
    else
      fail "shellcheck: $script has warnings — run: shellcheck $script"
    fi
  done < <(find . -name "*.sh" \
    ! -path "./.git/*" \
    ! -path "./node_modules/*" \
    | sort)
else
  echo "  INFO: shellcheck not found — skipping (install: https://www.shellcheck.net)"
fi

# ---------------------------------------------------------------------------
echo ""
echo "=== Stale version strings ==="

PLUGIN_VERSION="$(jq -r '.version' .claude-plugin/plugin.json)"

# copilot-instructions.md must match plugin.json version
COPILOT_VERSION="$(grep '^# Version:' .github/copilot-instructions.md | awk '{print $3}' || true)"
if [ "$COPILOT_VERSION" = "$PLUGIN_VERSION" ]; then
  pass ".github/copilot-instructions.md version matches plugin.json ($PLUGIN_VERSION)"
else
  fail ".github/copilot-instructions.md says Version: $COPILOT_VERSION but plugin.json is $PLUGIN_VERSION"
fi

if grep -q "install.sh --copilot" .github/copilot-instructions.md; then
  pass ".github/copilot-instructions.md documents installer path"
else
  fail ".github/copilot-instructions.md should document install.sh --copilot"
fi

while IFS= read -r copilot_ref; do
  if [ -f "$copilot_ref" ]; then
    pass ".github/copilot-instructions.md reference exists: $copilot_ref"
  else
    fail ".github/copilot-instructions.md references missing file: $copilot_ref"
  fi
done < <(grep -oE 'references/[a-z0-9-]+\.md' .github/copilot-instructions.md | sort -u)

# Cursor rules must match plugin.json version
CURSORRULES_VERSION="$(grep '^# Platform Engineering Rules — platform-skills v' .cursorrules | sed -E 's/.* v([0-9]+\.[0-9]+\.[0-9]+)$/\1/' || true)"
if [ "$CURSORRULES_VERSION" = "$PLUGIN_VERSION" ]; then
  pass ".cursorrules version matches plugin.json ($PLUGIN_VERSION)"
else
  fail ".cursorrules says Version: $CURSORRULES_VERSION but plugin.json is $PLUGIN_VERSION"
fi

CURSOR_MDC_VERSION="$(grep '^# Platform Skills — v' .cursor/rules/platform-skills.mdc | sed -E 's/.* v([0-9]+\.[0-9]+\.[0-9]+)$/\1/' || true)"
if [ "$CURSOR_MDC_VERSION" = "$PLUGIN_VERSION" ]; then
  pass ".cursor/rules/platform-skills.mdc version matches plugin.json ($PLUGIN_VERSION)"
else
  fail ".cursor/rules/platform-skills.mdc says Version: $CURSOR_MDC_VERSION but plugin.json is $PLUGIN_VERSION"
fi

# INSTALLATION.md verify output must match plugin.json version
if grep -q "platform-skills  v${PLUGIN_VERSION}  enabled" INSTALLATION.md; then
  pass "INSTALLATION.md verify output matches v${PLUGIN_VERSION}"
else
  fail "INSTALLATION.md verify output does not match v${PLUGIN_VERSION} — update the expected claude plugin list output"
fi

# marketplace.json version must match plugin.json
MARKETPLACE_VERSION="$(jq -r '.plugins[0].version' .claude-plugin/marketplace.json)"
if [ "$MARKETPLACE_VERSION" = "$PLUGIN_VERSION" ]; then
  pass "marketplace.json version matches plugin.json ($PLUGIN_VERSION)"
else
  fail "marketplace.json version $MARKETPLACE_VERSION does not match plugin.json $PLUGIN_VERSION"
fi

# ---------------------------------------------------------------------------
echo ""
echo "=== Installer smoke test ==="

if [ -x install.sh ]; then
  pass "install.sh is executable"
else
  fail "install.sh is missing or not executable"
fi

if bash install.sh --help >/dev/null 2>&1; then
  pass "install.sh --help exits successfully"
else
  fail "install.sh --help failed"
fi

# ---------------------------------------------------------------------------
echo ""
echo "=== Adoption assets ==="

if [ -f PROMPTS.md ]; then
  pass "PROMPTS.md exists"
else
  fail "PROMPTS.md missing"
fi

if grep -q "PROMPTS.md" README.md && grep -q "PROMPTS.md" QUICKSTART.md; then
  pass "README.md and QUICKSTART.md link to PROMPTS.md"
else
  fail "README.md and QUICKSTART.md should link to PROMPTS.md"
fi

for asset in BEFORE_AFTER.md LAUNCH.md docs/TEAM_ROLLOUT.md docs/AWESOME_LIST_SUBMISSIONS.md examples/demo/README.md; do
  if [ -f "$asset" ]; then
    pass "$asset exists"
  else
    fail "$asset missing"
  fi
done

if grep -q "examples/demo/" README.md && grep -q "docs/TEAM_ROLLOUT.md" README.md; then
  pass "README.md links demo gallery and team rollout"
else
  fail "README.md should link examples/demo/ and docs/TEAM_ROLLOUT.md"
fi

for template in \
  .github/ISSUE_TEMPLATE/agent_editor_support.md \
  .github/ISSUE_TEMPLATE/domain_guide_request.md \
  .github/ISSUE_TEMPLATE/example_contribution.md; do
  if [ -f "$template" ]; then
    pass "$template exists"
  else
    fail "$template missing"
  fi
done

# ---------------------------------------------------------------------------
echo ""
echo "=== Count badges ==="

ACTUAL_REF_GUIDES="$(find references -maxdepth 1 -name "*.md" | wc -l | tr -d ' ')"
ACTUAL_EXAMPLE_SETS="$(find examples -mindepth 2 -name README.md | wc -l | tr -d ' ')"

if grep -q "Reference%20Guides-${ACTUAL_REF_GUIDES}" README.md; then
  pass "README.md reference guide badge matches $ACTUAL_REF_GUIDES"
else
  fail "README.md reference guide badge should show $ACTUAL_REF_GUIDES"
fi

if grep -q "Example%20Sets-${ACTUAL_EXAMPLE_SETS}" README.md; then
  pass "README.md example set badge matches $ACTUAL_EXAMPLE_SETS"
else
  fail "README.md example set badge should show $ACTUAL_EXAMPLE_SETS"
fi

# ---------------------------------------------------------------------------
echo ""
echo "=== Demo gallery ==="

if [ -f examples/demo/README.md ]; then
  pass "examples/demo/README.md exists"
else
  fail "examples/demo/README.md missing"
fi

while IFS= read -r demo_dir; do
  demo_name="$(basename "$demo_dir")"

  if grep -qE "^>? ?Status: (Stable|Beta|Draft|Experimental)" "$demo_dir/README.md" 2>/dev/null; then
    pass "$demo_name README has valid Status label"
  else
    fail "$demo_name README missing valid Status label"
  fi

  for required_asset in README.md demo.gif demo.tape; do
    if [ -f "$demo_dir/$required_asset" ]; then
      pass "$demo_name has $required_asset"
    else
      fail "$demo_name missing $required_asset"
    fi
  done

  if [ -f "$demo_dir/demo.gif" ]; then
    gif_size="$(wc -c < "$demo_dir/demo.gif" | tr -d ' ')"
    if [ "$gif_size" -le 2000000 ]; then
      pass "$demo_name demo.gif size is under 2 MB"
    else
      fail "$demo_name demo.gif is ${gif_size} bytes; keep demo GIFs under 2 MB"
    fi
  fi

  if find "$demo_dir" -maxdepth 1 \( -name "bad.*" -o -name "deployment.yaml" \) | grep -q .; then
    pass "$demo_name has risky input fixture"
  else
    fail "$demo_name missing risky input fixture"
  fi

  if find "$demo_dir" -maxdepth 1 \( -name "fixed.*" -o -name "deployment-fixed.yaml" \) | grep -q .; then
    pass "$demo_name has safer output fixture"
  else
    fail "$demo_name missing safer output fixture"
  fi
done < <(find examples/demo -mindepth 1 -maxdepth 1 -type d | sort)

# ---------------------------------------------------------------------------
echo ""
echo "=== Internal Markdown link targets ==="

BROKEN=0
while IFS= read -r md_file; do
  dir="$(dirname "$md_file")"
  # Strip fenced code blocks before extracting links (avoids matching example links inside ```)
  stripped="$(awk '/^```/{in_fence=!in_fence; next} !in_fence' "$md_file")"
  # Extract relative Markdown links: [text](path) — skip anchors, external URLs, and mailto
  while IFS= read -r link; do
    # Skip external links, anchors-only, and template placeholders
    if echo "$link" | grep -qE "^https?://|^mailto:|^#|YOUR_|PLACEHOLDER"; then
      continue
    fi
    # Strip anchor fragment
    target="${link%%#*}"
    [ -z "$target" ] && continue
    # Strip trailing slash for directory link resolution
    target_path="${target%/}"
    # Resolve relative to the markdown file's directory
    resolved="$dir/$target_path"
    if [ ! -e "$resolved" ]; then
      fail "Broken link in $md_file: [$target] → $resolved does not exist"
      BROKEN=$((BROKEN + 1))
    fi
  done < <(echo "$stripped" | grep -oE '\]\([^)]+\)' | sed 's/^](\(.*\))$/\1/')
done < <(find . -name "*.md" \
  ! -path "./.git/*" \
  ! -path "./node_modules/*" \
  ! -path "./skills/*" \
  | sort)

if [ "$BROKEN" -eq 0 ]; then
  pass "No broken internal Markdown links found"
fi

# ---------------------------------------------------------------------------
echo ""

if [ "$ERRORS" -gt 0 ]; then
  echo "FAIL: $ERRORS validation error(s)"
  exit 1
fi
echo "PASS: all CI quality gate checks passed"
