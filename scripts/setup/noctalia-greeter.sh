#!/usr/bin/env bash
# Setup Noctalia Greeter with greetd following official Noctalia Greeter docs
# and the upstream /usr/share/noctalia-greeter/setup_greeter_system.sh helper.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

VT="1"
PINNED_SESSION=""
SWITCH_NOW=0

usage() {
  cat <<'EOF'
Usage: noctalia-greeter.sh [OPTIONS]

Configure greetd + noctalia-greeter according to the official Noctalia docs:
  1. Run upstream setup_greeter_system.sh (PAM module, /var/lib/noctalia-greeter, greeter.toml)
  2. Back up and write /etc/greetd/config.toml pointing to /usr/bin/noctalia-greeter-session
  3. Disable any active display manager (sddm, gdm, lightdm, etc.) and enable greetd.service
  4. Run 'noctalia msg greeter-sync' if Noctalia Shell is active

Options:
      --vt <num|next|current>   VT in /etc/greetd/config.toml (default: 1)
      --session <name>          Optional pinned desktop session name for --session
      --switch-now              Immediately stop old DM and start greetd now (restarts graphical session!)
      --dry-run                 Print actions without modifying system state
  -h, --help                    Show this help message and exit
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vt)
      [[ $# -ge 2 ]] || { log_error "--vt requires an argument"; exit 1; }
      VT="$2"
      shift 2
      ;;
    --session)
      [[ $# -ge 2 ]] || { log_error "--session requires an argument"; exit 1; }
      PINNED_SESSION="$2"
      shift 2
      ;;
    --switch-now)
      SWITCH_NOW=1
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

session_bin="$(command -v noctalia-greeter-session || true)"
if [[ -z "$session_bin" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    session_bin="/usr/bin/noctalia-greeter-session"
    log_warn "noctalia-greeter is not installed; previewing planned commands."
  else
    log_error "noctalia-greeter-session not found. Install noctalia-greeter and greetd first."
    exit 1
  fi
fi

if ! command -v greetd >/dev/null 2>&1; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_warn "greetd is not installed; previewing planned commands."
  else
    log_error "greetd is not installed. Install greetd first (sudo pacman -S --needed greetd)."
    exit 1
  fi
fi

greeter_user="greeter"
if ! id -u "$greeter_user" >/dev/null 2>&1; then
  log_info "Creating system user '${greeter_user}'..."
  run_cmd sudo useradd -r -s /usr/bin/nologin -d /var/lib/noctalia-greeter "$greeter_user"
fi

upstream_setup="/usr/share/noctalia-greeter/setup_greeter_system.sh"
if [[ -x "$upstream_setup" ]]; then
  log_info "Running official upstream helper: ${upstream_setup}"
  run_cmd sudo env GREETER_USER="$greeter_user" "$upstream_setup"
else
  log_warn "Upstream helper not found at ${upstream_setup}; applying equivalent manual setup..."
  run_cmd sudo mkdir -p /var/lib/noctalia-greeter
  run_cmd sudo chmod 0750 /var/lib/noctalia-greeter
  run_cmd sudo chown -R "${greeter_user}:${greeter_user}" /var/lib/noctalia-greeter
  if command -v noctalia-greeter-apply-appearance >/dev/null 2>&1; then
    run_cmd sudo env GREETER_USER="$greeter_user" noctalia-greeter-apply-appearance --setup-system
  fi
fi

greetd_cmd="$session_bin"
if [[ -n "$PINNED_SESSION" ]]; then
  greetd_cmd="${session_bin} -- --session ${PINNED_SESSION}"
fi

greetd_cfg="/etc/greetd/config.toml"
log_info "Configuring ${greetd_cfg}..."
if [[ -f "$greetd_cfg" ]]; then
  run_cmd sudo cp -a "$greetd_cfg" "${greetd_cfg}.bak.$(date +%Y%m%d-%H%M%S)"
fi
run_cmd sudo mkdir -p /etc/greetd

if [[ "$DRY_RUN" -eq 1 ]]; then
  printf '[DRY-RUN] write %s (vt=%s, command=%q, user=%s)\n' "$greetd_cfg" "$VT" "$greetd_cmd" "$greeter_user"
else
  tmp_cfg="$(mktemp)"
  trap 'rm -f -- "$tmp_cfg"' EXIT
  cat > "$tmp_cfg" <<EOF
[terminal]
vt = ${VT}

[default_session]
command = "${greetd_cmd}"
user = "${greeter_user}"
EOF
  sudo install -m 0644 "$tmp_cfg" "$greetd_cfg"
fi

if command -v systemctl >/dev/null 2>&1; then
  for dm in sddm gdm lightdm lxdm ly plasma-login-manager; do
    if systemctl is-enabled --quiet "${dm}.service" 2>/dev/null; then
      log_info "Disabling existing display manager: ${dm}.service"
      if [[ "$SWITCH_NOW" -eq 1 ]]; then
        run_cmd sudo systemctl disable --now "${dm}.service"
      else
        run_cmd sudo systemctl disable "${dm}.service"
      fi
    fi
  done

  log_info "Enabling greetd.service..."
  if [[ "$SWITCH_NOW" -eq 1 ]]; then
    run_cmd sudo systemctl enable --now greetd.service
  else
    run_cmd sudo systemctl enable greetd.service
    log_info "greetd.service enabled for next boot/reboot (pass --switch-now to switch immediately)."
  fi
fi

if command -v noctalia >/dev/null 2>&1 && pgrep -x noctalia >/dev/null 2>&1; then
  log_info "Syncing Noctalia Shell appearance to Noctalia Greeter..."
  run_cmd noctalia msg greeter-sync || true
fi

log_info "Noctalia Greeter setup complete."
