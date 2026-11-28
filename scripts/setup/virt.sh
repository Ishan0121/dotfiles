#!/usr/bin/env bash
# Setup libvirt / virt-manager daemon, group membership, and default NAT network.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

usage() {
  cat <<'EOF'
Usage: virt.sh [OPTIONS]

Enable and start libvirtd.service, add the current user to the 'libvirt' group,
and ensure the default NAT network is started and autostarted.

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

if ! command -v virsh >/dev/null 2>&1; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_warn "virsh/libvirt is not installed; previewing planned commands."
  else
    log_error "virsh is not installed. Install virt-manager / libvirt first."
    exit 1
  fi
fi

log_info "Enabling and starting libvirtd.service..."
run_cmd sudo systemctl enable --now libvirtd.service

if id -nG "$USER" | grep -qw 'libvirt'; then
  log_info "User '${USER}' is already in the 'libvirt' group."
else
  log_info "Adding '${USER}' to the 'libvirt' group..."
  run_cmd sudo usermod -aG libvirt "$USER"
  log_warn "Log out and back in for 'libvirt' group membership to take effect."
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  run_cmd sudo virsh net-autostart default
  run_cmd sudo virsh net-start default
else
  if sudo virsh net-info default >/dev/null 2>&1; then
    run_cmd sudo virsh net-autostart default
    if ! sudo virsh net-info default | grep -qE '^Active:[[:space:]]+yes'; then
      run_cmd sudo virsh net-start default
    else
      log_info "Libvirt 'default' network is already active."
    fi
  else
    log_warn "Libvirt 'default' network definition not found; define it in virt-manager if needed."
  fi
fi

log_info "Virtualization setup complete."
