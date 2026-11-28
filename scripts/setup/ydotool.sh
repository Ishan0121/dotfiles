#!/usr/bin/env bash
# Setup ydotool daemon (ydotool.service) and uinput permissions per Arch Wiki.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

usage() {
  cat <<'EOF'
Usage: ydotool.sh [OPTIONS]

Configure /dev/uinput access (input group + udev reload) and enable/start
the ydotool.service systemd user daemon.

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

if ! command -v ydotool >/dev/null 2>&1 || ! command -v ydotoold >/dev/null 2>&1; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_warn "ydotool is not installed; previewing planned commands."
  else
    log_error "ydotool is not installed. Install it via packages/desktop.txt first."
    exit 1
  fi
fi

if id -nG "$USER" | grep -qw 'input'; then
  log_info "User '${USER}' is already in the 'input' group."
else
  log_info "Adding '${USER}' to the 'input' group for /dev/uinput access..."
  run_cmd sudo usermod -aG input "$USER"
  log_warn "Log out and back in for 'input' group membership to take effect."
fi

if [[ ! -f /usr/lib/udev/rules.d/80-uinput.rules && ! -f /etc/udev/rules.d/80-uinput.rules ]]; then
  log_info "Installing /etc/udev/rules.d/80-uinput.rules..."
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[DRY-RUN] write /etc/udev/rules.d/80-uinput.rules\n'
  else
    printf 'KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"\n' \
      | sudo tee /etc/udev/rules.d/80-uinput.rules >/dev/null
  fi
fi

if command -v udevadm >/dev/null 2>&1; then
  run_cmd sudo udevadm control --reload-rules
  run_cmd sudo udevadm trigger --name-match=uinput
fi

if command -v systemctl >/dev/null 2>&1; then
  log_info "Enabling and starting ydotool.service..."
  run_cmd systemctl --user daemon-reload
  run_cmd systemctl --user enable --now ydotool.service
fi

log_info "ydotool setup complete."
