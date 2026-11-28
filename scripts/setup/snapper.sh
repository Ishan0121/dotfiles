#!/usr/bin/env bash
# Setup Snapper Btrfs root snapshots, cleanup timer, and grub-btrfsd per Arch Wiki.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

ENABLE_TIMELINE=0

usage() {
  cat <<'EOF'
Usage: snapper.sh [OPTIONS]

Configure Snapper on Btrfs per Arch Wiki:
  - Create 'root' config for / if missing
  - Enable snapper-cleanup.timer (and snapper-timeline.timer with --enable-timeline)
  - Enable grub-btrfsd.service if GRUB is detected

Options:
      --enable-timeline    Also enable snapper-timeline.timer (hourly snapshots)
      --dry-run            Print actions without modifying system state
  -h, --help               Show this help message and exit
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --enable-timeline)
      ENABLE_TIMELINE=1
      shift
      ;;
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

if ! command -v snapper >/dev/null 2>&1; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_warn "snapper is not installed; previewing planned commands."
  else
    log_error "snapper is not installed. Install it via packages/arch.txt first."
    exit 1
  fi
fi

if [[ "$DRY_RUN" -eq 0 ]] && ! snapper list-configs 2>/dev/null | grep -qE '^root[[:space:]]'; then
  log_info "Creating snapper 'root' config for /..."
  run_cmd sudo snapper -c root create-config /
else
  log_info "Snapper 'root' config already present (or dry-run)."
fi

log_info "Enabling snapper-cleanup.timer..."
run_cmd sudo systemctl enable --now snapper-cleanup.timer

if [[ "$ENABLE_TIMELINE" -eq 1 ]]; then
  log_info "Enabling snapper-timeline.timer..."
  run_cmd sudo systemctl enable --now snapper-timeline.timer
fi

if [[ -f /boot/grub/grub.cfg ]] && systemctl list-unit-files grub-btrfsd.service --no-legend 2>/dev/null | grep -qF 'grub-btrfsd.service'; then
  log_info "GRUB detected; enabling grub-btrfsd.service..."
  run_cmd sudo systemctl enable --now grub-btrfsd.service
fi

log_info "Snapper setup complete."
