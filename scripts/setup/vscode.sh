#!/usr/bin/env bash
# Install missing VS Code extensions from packages/vscode-extensions.txt.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

usage() {
  cat <<'EOF'
Usage: vscode.sh [OPTIONS]

Install missing extensions listed in packages/vscode-extensions.txt using
'code' (or 'codium' fallback).

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

code_bin=""
if command -v code >/dev/null 2>&1; then
  code_bin="code"
elif command -v codium >/dev/null 2>&1; then
  code_bin="codium"
elif [[ "$DRY_RUN" -eq 1 ]]; then
  code_bin="code"
  log_warn "code/codium is not installed; previewing planned commands."
else
  log_error "Neither code nor codium is installed. Install visual-studio-code-bin first."
  exit 1
fi

manifest="${DOTFILES_ROOT}/packages/vscode-extensions.txt"
declare -A installed=()
if [[ "$DRY_RUN" -eq 0 ]]; then
  while IFS= read -r ext; do
    [[ -n "$ext" ]] && installed["${ext,,}"]=1
  done < <("$code_bin" --list-extensions 2>/dev/null || true)
fi

count=0
while IFS= read -r ext; do
  [[ -z "$ext" ]] && continue
  if [[ -n "${installed[${ext,,}]+x}" ]]; then
    continue
  fi
  run_cmd "$code_bin" --install-extension "$ext"
  count=$((count + 1))
done < <(read_pkg_list "$manifest")

log_info "VS Code setup complete (${count} extension(s) processed)."
