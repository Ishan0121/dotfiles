#!/usr/bin/env bash
# Install missing Antigravity IDE extensions from packages/antigravity-extensions.txt.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

usage() {
  cat <<'EOF'
Usage: antigravity.sh [OPTIONS]

Install missing extensions listed in packages/antigravity-extensions.txt using
'antigravity-ide'.

Options:
      --dry-run    Print install commands without executing them
  -h, --help       Show this help message and exit
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      export DRY_RUN
      shift
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

bin="antigravity-ide"
if ! command -v "$bin" >/dev/null 2>&1; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_warn "antigravity-ide is not installed; previewing planned commands."
  else
    log_error "antigravity-ide is not installed. Install it via packages/aur.txt first."
    exit 1
  fi
fi

manifest="${DOTFILES_ROOT}/packages/antigravity-extensions.txt"
declare -A installed=()
if [[ "$DRY_RUN" -eq 0 ]]; then
  while IFS= read -r ext; do
    [[ -n "$ext" ]] && installed["${ext,,}"]=1
  done < <("$bin" --list-extensions 2>/dev/null || true)
fi

count=0
while IFS= read -r ext; do
  [[ -z "$ext" ]] && continue
  if [[ -n "${installed[${ext,,}]+x}" ]]; then
    continue
  fi
  run_cmd "$bin" --install-extension "$ext"
  count=$((count + 1))
done < <(read_pkg_list "$manifest")

log_info "Antigravity IDE setup complete (${count} extension(s) processed)."
