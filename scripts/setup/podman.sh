#!/usr/bin/env bash
# Setup rootless Podman (subuid/subgid ranges and podman.socket) per Arch Wiki.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

usage() {
  cat <<'EOF'
Usage: podman.sh [OPTIONS]

Configure /etc/subuid and /etc/subgid for rootless Podman (if missing) and
enable/start the podman.socket user unit.

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

if ! command -v podman >/dev/null 2>&1; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_warn "podman is not installed; previewing planned commands."
  else
    log_error "podman is not installed. Install it via packages/development.txt first."
    exit 1
  fi
fi

if [[ ! -f /etc/subuid ]] || ! grep -q "^${USER}:" /etc/subuid; then
  log_info "Configuring /etc/subuid and /etc/subgid for '${USER}'..."
  run_cmd sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 "$USER"
else
  log_info "/etc/subuid already configured for '${USER}'."
fi

if command -v systemctl >/dev/null 2>&1; then
  log_info "Enabling and starting podman.socket..."
  run_cmd systemctl --user daemon-reload
  run_cmd systemctl --user enable --now podman.socket
fi

log_info "Podman setup complete."
