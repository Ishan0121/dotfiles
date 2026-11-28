#!/usr/bin/env bash
# Setup paccache.timer (pacman-contrib) and fstrim.timer per Arch Wiki.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

usage() {
  cat <<'EOF'
Usage: paccache.sh [OPTIONS]

Enable weekly pacman package cache cleanup (paccache.timer from pacman-contrib)
and weekly SSD/NVMe TRIM (fstrim.timer) per Arch Wiki.

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

if ! command -v paccache >/dev/null 2>&1; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_warn "paccache (pacman-contrib) is not installed; previewing planned commands."
  else
    log_error "paccache is not installed. Install pacman-contrib via packages/arch.txt first."
    exit 1
  fi
fi

log_info "Enabling paccache.timer..."
run_cmd sudo systemctl enable --now paccache.timer

log_info "Enabling fstrim.timer..."
run_cmd sudo systemctl enable --now fstrim.timer

log_info "Pacman cache & TRIM timers setup complete."
