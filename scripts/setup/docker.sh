#!/usr/bin/env bash
# Setup Docker daemon and user group membership per Arch Wiki.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

usage() {
  cat <<'EOF'
Usage: docker.sh [OPTIONS]

Enable and start docker.service and add the current user to the 'docker' group.

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

if ! command -v docker >/dev/null 2>&1; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_warn "docker is not installed; previewing planned commands."
  else
    log_error "docker is not installed. Install it via packages/development.txt first."
    exit 1
  fi
fi

log_info "Enabling and starting docker.service..."
run_cmd sudo systemctl enable --now docker.service

if id -nG "$USER" | grep -qw 'docker'; then
  log_info "User '${USER}' is already in the 'docker' group."
else
  log_info "Adding '${USER}' to the 'docker' group..."
  run_cmd sudo usermod -aG docker "$USER"
  log_warn "Log out and back in for 'docker' group membership to take effect."
fi

log_info "Docker setup complete."
