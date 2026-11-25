#!/usr/bin/env bash
# Tier 4: --help and --dry-run checks for bootstrap, package, external, and dep scripts.

set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="${REPO_ROOT}/scripts"
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

echo "=== Tier 4: Bootstrap & Dry-Run Checks ==="

TMP_HOME="$(mktemp -d)"
TMP_BACKUP="$(mktemp -d)"
TMP_DIRS+=("$TMP_HOME" "$TMP_BACKUP")

# 1. --help on all CLI scripts
for script in bootstrap.sh install-packages.sh setup-externals.sh check-deps.sh; do
  "${SCRIPTS_DIR}/${script}" --help >/dev/null \
    || fail "${script} --help exited non-zero"
done
pass "--help succeeded on bootstrap.sh, install-packages.sh, setup-externals.sh, check-deps.sh"

# 2. check-deps.sh execution
"${SCRIPTS_DIR}/check-deps.sh" >/dev/null \
  || fail "check-deps.sh failed"
pass "check-deps.sh succeeded"

# 3. install-packages.sh --dry-run for arch and fedora
"${SCRIPTS_DIR}/install-packages.sh" --dry-run --distro arch >/dev/null \
  || fail "install-packages.sh --dry-run --distro arch failed"
"${SCRIPTS_DIR}/install-packages.sh" --dry-run --distro fedora >/dev/null \
  || fail "install-packages.sh --dry-run --distro fedora failed"
pass "install-packages.sh --dry-run succeeded for arch and fedora"

# 4. setup-externals.sh --dry-run against isolated $TMP_HOME
"${SCRIPTS_DIR}/setup-externals.sh" --dry-run --target "$TMP_HOME" >/dev/null \
  || fail "setup-externals.sh --dry-run failed"
pass "setup-externals.sh --dry-run succeeded"

# 5. bootstrap.sh --dry-run against isolated $TMP_HOME and $TMP_BACKUP
"${SCRIPTS_DIR}/bootstrap.sh" --dry-run --target "$TMP_HOME" --backup-dir "$TMP_BACKUP" >/dev/null \
  || fail "bootstrap.sh --dry-run failed"
pass "bootstrap.sh --dry-run succeeded"

# 6. Verify zero mutations to $TMP_HOME and $TMP_BACKUP
home_entries="$(find "$TMP_HOME" -mindepth 1)"
backup_entries="$(find "$TMP_BACKUP" -mindepth 1)"
[[ -z "$home_entries" ]] || fail "Dry-run mutated TMP_HOME: ${home_entries}"
[[ -z "$backup_entries" ]] || fail "Dry-run mutated TMP_BACKUP: ${backup_entries}"
pass "Verified zero mutations to isolated TMP_HOME and TMP_BACKUP"

echo "=== Tier 4 Complete ==="
