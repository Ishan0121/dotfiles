#!/usr/bin/env bash
# Setup UFW firewall defaults and systemd service per Arch Wiki.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

usage() {
  cat <<'EOF'
Usage: ufw.sh [OPTIONS]

Configure UFW defaults (deny incoming, allow outgoing, allow in on tailscale0
when Tailscale is installed) and enable/start ufw.service.

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

if ! command -v ufw >/dev/null 2>&1; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_warn "ufw is not installed; previewing planned commands."
  else
    log_error "ufw is not installed. Install it via packages/common.txt first."
    exit 1
  fi
fi

log_info "Configuring UFW default policies..."
run_cmd sudo ufw default deny incoming
run_cmd sudo ufw default allow outgoing
if command -v tailscale >/dev/null 2>&1; then
  run_cmd sudo ufw allow in on tailscale0
fi

log_info "Enabling ufw.service and activating firewall..."
run_cmd sudo systemctl enable --now ufw.service
run_cmd sudo ufw --force enable

log_info "UFW setup complete."
