#!/usr/bin/env bash
# Setup Voxtype with Whisper (base.en), systemd user service, and input group check.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

TARGET_DIR="$HOME"
MODEL="base.en"
SKIP_INPUT_GROUP=0

usage() {
  cat <<'EOF'
Usage: voxtype.sh [OPTIONS]

Configure Voxtype to use Whisper (default model: base.en), download the model
if missing, add the current user to the 'input' group (unless skipped), and
enable/start voxtype.service.

Options:
      --target <dir>         Target home directory (default: $HOME)
      --model <name>         Whisper model to configure/download (default: base.en)
      --skip-input-group     Skip adding $USER to the 'input' group
      --dry-run              Print actions without modifying system state
  -h, --help                 Show this help message and exit
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      [[ $# -ge 2 ]] || { log_error "--target requires an argument"; exit 1; }
      TARGET_DIR="$2"
      shift 2
      ;;
    --model)
      [[ $# -ge 2 ]] || { log_error "--model requires an argument"; exit 1; }
      MODEL="$2"
      shift 2
      ;;
    --skip-input-group)
      SKIP_INPUT_GROUP=1
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

if ! command -v voxtype >/dev/null 2>&1; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_warn "voxtype is not installed; previewing planned commands."
  else
    log_error "voxtype is not installed. Install it via packages/aur.txt first."
    exit 1
  fi
fi

cfg_file="${TARGET_DIR}/.config/voxtype/config.toml"
model_file="${TARGET_DIR}/.local/share/voxtype/models/ggml-${MODEL}.bin"

if [[ ! -f "$cfg_file" ]]; then
  log_warn "Voxtype config not found at ${cfg_file}; run stow-manage.sh deploy first for your stowed config."
else
  if ! grep -qE '^[[:space:]]*engine[[:space:]]*=[[:space:]]*"whisper"' "$cfg_file"; then
    log_info "Setting Voxtype engine to whisper..."
    run_cmd voxtype --config "$cfg_file" config set engine whisper
  else
    log_info "Voxtype engine already set to whisper in ${cfg_file}."
  fi

  if ! grep -qE "^[[:space:]]*model[[:space:]]*=[[:space:]]*\"${MODEL}\"" "$cfg_file"; then
    log_info "Setting Whisper model to ${MODEL}..."
    run_cmd voxtype --config "$cfg_file" config set whisper.model "$MODEL"
  else
    log_info "Whisper model already set to ${MODEL} in ${cfg_file}."
  fi
fi

if [[ -f "$model_file" ]]; then
  log_info "Whisper model already downloaded: ${model_file}"
else
  log_info "Downloading Whisper model '${MODEL}'..."
  run_cmd voxtype setup --download --model "$MODEL" --no-post-install
fi

if [[ "$SKIP_INPUT_GROUP" -eq 0 ]]; then
  if id -nG "$USER" | grep -qw 'input'; then
    log_info "User '${USER}' is already in the 'input' group."
  else
    log_info "Adding '${USER}' to the 'input' group for built-in push-to-talk hotkey support..."
    run_cmd sudo usermod -aG input "$USER"
    log_warn "Log out and back in for the 'input' group change to take effect (compositor keybind Mod+H works immediately)."
  fi
fi

if command -v systemctl >/dev/null 2>&1; then
  log_info "Enabling and starting voxtype.service..."
  run_cmd systemctl --user daemon-reload
  run_cmd systemctl --user enable --now voxtype.service
  if [[ "$DRY_RUN" -eq 0 ]] && systemctl --user is-active --quiet voxtype.service; then
    run_cmd systemctl --user restart voxtype.service
  fi
fi

if [[ "$DRY_RUN" -eq 0 ]] && command -v voxtype >/dev/null 2>&1; then
  log_info "Running voxtype doctor..."
  voxtype doctor || log_warn "voxtype doctor reported warnings/errors (see above; relogin may be needed if 'input' group was just added)."
fi

log_info "Voxtype setup complete."
