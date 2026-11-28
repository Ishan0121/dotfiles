#!/usr/bin/env bash
# Setup Tailscale daemon and check login state per Arch Wiki.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

usage() {
  cat <<'EOF'
Usage: tailscale.sh [OPTIONS]

Enable and start tailscaled.service and check Tailscale authentication status.

Options:
      --dry-run    Print actions without modifying system state
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

if ! command -v tailscale >/dev/null 2>&1; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_warn "tailscale is not installed; previewing planned commands."
  else
    log_error "tailscale is not installed. Install it via packages/common.txt first."
    exit 1
  fi
fi

log_info "Enabling and starting tailscaled.service..."
run_cmd sudo systemctl enable --now tailscaled.service

if [[ "$DRY_RUN" -eq 0 ]]; then
  if ! tailscale status >/dev/null 2>&1; then
    log_warn "Tailscale is not logged in yet. Run 'sudo tailscale up' to authenticate."
  else
    log_info "Tailscale is connected."
  fi
fi

log_info "Tailscale setup complete."
