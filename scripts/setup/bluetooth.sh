#!/usr/bin/env bash
# Setup Bluetooth service (bluetooth.service) per Arch Wiki.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

usage() {
  cat <<'EOF'
Usage: bluetooth.sh [OPTIONS]

Enable and start bluetooth.service (bluez).

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

if ! command -v bluetoothctl >/dev/null 2>&1; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_warn "bluetoothctl/bluez is not installed; previewing planned commands."
  else
    log_error "bluetoothctl is not installed. Install bluez / blueman first."
    exit 1
  fi
fi

log_info "Enabling and starting bluetooth.service..."
run_cmd sudo systemctl enable --now bluetooth.service

log_info "Bluetooth setup complete."
