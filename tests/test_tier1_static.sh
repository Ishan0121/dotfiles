#!/usr/bin/env bash
# Tier 1: Static analysis, shellcheck, secret scanning, and .gitignore spot checks.

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIRS=()

cleanup() {
  local d
  for d in "${TMP_DIRS[@]}"; do
    [[ -n "$d" && -d "$d" ]] && rm -rf "$d"
  done
}
trap cleanup EXIT

pass() { printf '[PASS] %s\n' "$*"; }
fail() { printf '[FAIL] %s\n' "$*" >&2; exit 1; }

echo "=== Tier 1: Static & Security Checks ==="

# 1. bash -n and shellcheck -x on all scripts and tests
shopt -s nullglob
bash_targets=(
  "${REPO_ROOT}"/scripts/*.sh
  "${REPO_ROOT}"/scripts/lib/*.sh
  "${REPO_ROOT}"/tests/*.sh
)
shopt -u nullglob

[[ ${#bash_targets[@]} -gt 0 ]] || fail "No shell scripts found to lint"

for f in "${bash_targets[@]}"; do
  bash -n "$f" || fail "bash -n failed: $f"
  (cd -- "$(dirname -- "$f")" && shellcheck -x "$(basename -- "$f")") || fail "shellcheck -x failed: $f"
done
pass "bash -n and shellcheck -x passed on ${#bash_targets[@]} script(s)"

# 2. Positive secret scan on repository root
"${REPO_ROOT}/scripts/check-secrets.sh" --root "$REPO_ROOT" >/dev/null \
  || fail "check-secrets.sh failed on ${REPO_ROOT}"
pass "check-secrets.sh passed on ${REPO_ROOT} (exit 0)"

# 3. Negative secret scan using a synthetic token in an isolated temp directory
tmp_repo="$(mktemp -d)"
TMP_DIRS+=("$tmp_repo")
mkdir -p "${tmp_repo}/stow/foo"
printf 'api_token = "sk-1234567890abcdefghijklmnop"\n' > "${tmp_repo}/stow/foo/bad.conf"

if "${REPO_ROOT}/scripts/check-secrets.sh" --root "$tmp_repo" >/dev/null 2>&1; then
  fail "Negative test failed: check-secrets.sh exited 0 on synthetic sk-* token"
fi
pass "Negative test passed: check-secrets.sh detected synthetic sk-* token (non-zero exit)"

# 4. git check-ignore spot checks
ignored_paths=(
  "stow/noctalia/.config/noctalia/secrets.env"
  ".env"
  "stow/foo/my_secret.toml"
  "stow/umbriel/.config/umbriel/outputs.toml"
  "stow/umbriel/.config/umbriel/noctalia.toml"
  "stow/nvim/.config/nvim/.git"
)
for p in "${ignored_paths[@]}"; do
  git -C "$REPO_ROOT" check-ignore --no-index -q "$p" \
    || fail "Expected path to be git-ignored: $p"
done
pass "git check-ignore confirmed secret/runtime paths are ignored"

tracked_paths=(
  "stow/noctalia/.config/noctalia/secrets.env.example"
  "stow/umbriel/.config/umbriel/outputs.toml.example"
  "scripts/check-secrets.sh"
)
for p in "${tracked_paths[@]}"; do
  if git -C "$REPO_ROOT" check-ignore --no-index -q "$p"; then
    fail "Expected path NOT to be git-ignored: $p"
  fi
done
pass "git check-ignore confirmed .example files and check-secrets.sh are not ignored"

echo "=== Tier 1 Complete ==="
