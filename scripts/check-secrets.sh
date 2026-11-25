#!/usr/bin/env bash
# Scan stow/ and system/ for accidental secrets, databases, hardcoded paths, or nested .git directories.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

SCAN_ROOT="$DOTFILES_ROOT"

usage() {
  cat <<'EOF'
Usage: check-secrets.sh [OPTIONS]

Scan stow/ and system/ for secrets, credentials, databases, hardcoded user paths,
and nested .git directories. Exits non-zero if any finding is detected.

Options:
      --root <dir>    Repository root to scan (default: DOTFILES_ROOT)
  -h, --help          Show this help message and exit
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      [[ $# -ge 2 ]] || { log_error "--root requires an argument"; exit 1; }
      SCAN_ROOT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      usage >&2
      exit 1
      ;;
  esac
done

targets=()
for sub in stow system; do
  if [[ -d "${SCAN_ROOT}/${sub}" ]]; then
    targets+=("${SCAN_ROOT}/${sub}")
  fi
done

if [[ ${#targets[@]} -eq 0 ]]; then
  log_warn "No stow/ or system/ directories found under ${SCAN_ROOT}."
  exit 0
fi

findings=0

report_finding() {
  local label="$1"
  local detail="$2"
  log_error "[FINDING: ${label}] ${detail}"
  findings=$((findings + 1))
}

log_info "Scanning ${targets[*]}..."

# 1. Nested .git directories or files
while IFS= read -r -d '' git_entry; do
  report_finding "nested-git" "$git_entry"
done < <(find "${targets[@]}" -name '.git' -print0 2>/dev/null || true)

# 2. Database files (.vscdb, .db, .sqlite, .sqlite3)
while IFS= read -r -d '' db_file; do
  report_finding "database-file" "$db_file"
done < <(find "${targets[@]}" -type f \( -name '*.vscdb' -o -name '*.db' -o -name '*.sqlite' -o -name '*.sqlite3' \) -print0 2>/dev/null || true)

# 3. Private key headers
if matches="$(grep -rnE -- '-----BEGIN ([A-Z0-9 ]+ )?PRIVATE KEY-----' "${targets[@]}" 2>/dev/null || true)" && [[ -n "$matches" ]]; then
  report_finding "private-key" "$matches"
fi

# 4. Known token/API key prefixes
if matches="$(grep -rnE -- '(ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,})' "${targets[@]}" 2>/dev/null || true)" && [[ -n "$matches" ]]; then
  report_finding "api-token" "$matches"
fi

# 5. Non-placeholder password = / api_key = assignments
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  if printf '%s\n' "$line" | grep -qE '(REPLACE_WITH_|YOUR_|CHANGEME|""|'\'''\''|\$\{?[A-Za-z0-9_]+\}?)'; then
    continue
  fi
  report_finding "credential-assignment" "$line"
done < <(grep -rnE -- '^[[:space:]]*(password|api_key|wallhaven_api_key)[[:space:]]*=' "${targets[@]}" 2>/dev/null || true)

# 6. Hardcoded /home/phantom/ paths
if matches="$(grep -rnF -- '/home/phantom/' "${targets[@]}" 2>/dev/null || true)" && [[ -n "$matches" ]]; then
  report_finding "hardcoded-phantom-path" "$matches"
fi

# 7. Windows C:\Users paths
if matches="$(grep -rnF -- 'C:\Users' "${targets[@]}" 2>/dev/null || true)" && [[ -n "$matches" ]]; then
  report_finding "windows-path" "$matches"
fi

if [[ "$findings" -gt 0 ]]; then
  log_error "Secret scan failed with ${findings} finding(s)."
  exit 1
fi

log_info "Secret scan passed: 0 findings."
