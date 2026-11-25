#!/usr/bin/env bash
# Check required and optional dependencies for dotfiles management.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: check-deps.sh [OPTIONS]

Check required and optional tools needed for dotfiles management.

Options:
  -h, --help    Show this help message and exit
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
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

REQUIRED_TOOLS=(stow git rsync bash)
OPTIONAL_TOOLS=(shellcheck zsh nvim python3 curl paru yay pacman dnf)

missing_required=0

log_info "Checking required tools..."
for tool in "${REQUIRED_TOOLS[@]}"; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf '  [OK]      %s (%s)\n' "$tool" "$(command -v "$tool")"
  else
    printf '  [MISSING] %s\n' "$tool"
    missing_required=1
  fi
done

log_info "Checking optional tools..."
for tool in "${OPTIONAL_TOOLS[@]}"; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf '  [OK]      %s (%s)\n' "$tool" "$(command -v "$tool")"
  else
    printf '  [ABSENT]  %s\n' "$tool"
  fi
done

if [[ "$missing_required" -ne 0 ]]; then
  log_error "One or more required tools are missing."
  exit 1
fi

log_info "All required dependencies are available."
