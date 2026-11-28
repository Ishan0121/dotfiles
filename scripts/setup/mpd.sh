#!/usr/bin/env bash
# Setup Music Player Daemon (mpd) and mpd-mpris user services.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

TARGET_DIR="$HOME"

usage() {
  cat <<'EOF'
Usage: mpd.sh [OPTIONS]

Create required MPD directories and enable/start mpd.service and
mpd-mpris.service for the current user.

Options:
      --target <dir>    Target home directory (default: $HOME)
      --dry-run         Print actions without modifying system state
  -h, --help            Show this help message and exit
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      [[ $# -ge 2 ]] || { log_error "--target requires an argument"; exit 1; }
      TARGET_DIR="$2"
      shift 2
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

if ! command -v mpd >/dev/null 2>&1; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_warn "mpd is not installed; previewing planned commands."
  else
    log_error "mpd is not installed. Install it via packages/desktop.txt first."
    exit 1
  fi
fi

log_info "Ensuring MPD directories exist under ${TARGET_DIR}..."
run_cmd mkdir -p \
  "${TARGET_DIR}/Music" \
  "${TARGET_DIR}/.config/mpd/playlists" \
  "${TARGET_DIR}/.local/share/mpd" \
  "${TARGET_DIR}/.local/state/mpd"

if [[ ! -f "${TARGET_DIR}/.config/mpd/mpd.conf" ]]; then
  log_warn "MPD config not found at ${TARGET_DIR}/.config/mpd/mpd.conf; run stow-manage.sh deploy first."
fi

if command -v systemctl >/dev/null 2>&1; then
  run_cmd systemctl --user daemon-reload
  log_info "Enabling and starting mpd.service..."
  run_cmd systemctl --user enable --now mpd.service

  if [[ "$DRY_RUN" -eq 1 ]] || systemctl --user list-unit-files mpd-mpris.service --no-legend 2>/dev/null | grep -qF 'mpd-mpris.service'; then
    log_info "Enabling and starting mpd-mpris.service..."
    run_cmd systemctl --user enable --now mpd-mpris.service
  fi
fi

if [[ "$DRY_RUN" -eq 0 ]] && command -v mpc >/dev/null 2>&1; then
  mpc update >/dev/null 2>&1 || true
fi

log_info "MPD setup complete."
