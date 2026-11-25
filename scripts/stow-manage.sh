#!/usr/bin/env bash
# Deploy, undeploy, restow, or check status of GNU Stow packages.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

TARGET_DIR="$HOME"
BACKUP_DIR="$BACKUP_ROOT"
PROFILE="active"
FORCE_NOCTALIA_RENDER=0
ACTION=""

ALL_PACKAGES=(
  zsh bash git starship kitty alacritty foot cli media bin xdg
  umbriel noctalia hypr niri gtk qt desktop-extras
  nvim vscode antigravity zed
)

usage() {
  cat <<'EOF'
Usage: stow-manage.sh <ACTION> [OPTIONS]

Actions:
  deploy      Stow packages into target directory (using --no-folding)
  undeploy    Remove stowed symlinks from target directory
  restow      Re-stow packages cleanly
  status      Show dry-run stow status for selected profile

Options:
      --profile <active|all>     Profile to manage: active (20 pkgs, excludes hypr/niri)
                                 or all (all 22 pkgs) (default: active)
      --target <dir>             Target home directory (default: $HOME)
      --backup-dir <dir>         Backup directory reference (default: /mnt/nexus/dotfiles-backups)
      --force-noctalia-render    Overwrite existing target Noctalia config.toml
      --dry-run                  Simulate stow and file operations without modifying target
  -h, --help                     Show this help message and exit
EOF
}

get_profile_packages() {
  local pkg
  for pkg in "${ALL_PACKAGES[@]}"; do
    if [[ "$PROFILE" == "active" && ( "$pkg" == "hypr" || "$pkg" == "niri" ) ]]; then
      continue
    fi
    if [[ -d "${STOW_DIR}/${pkg}" ]]; then
      printf '%s\n' "$pkg"
    fi
  done
}

render_noctalia_config() {
  local template="${STOW_DIR}/noctalia/.config/noctalia/config.toml"
  local target_dir="${TARGET_DIR}/.config/noctalia"
  local target_cfg="${target_dir}/config.toml"
  local secrets_env="${target_dir}/secrets.env"

  if [[ ! -f "$template" ]]; then
    log_warn "Noctalia template not found: ${template}"
    return 0
  fi

  if [[ -e "$target_cfg" && "$FORCE_NOCTALIA_RENDER" -ne 1 ]]; then
    log_info "Preserving existing Noctalia config: ${target_cfg}"
    return 0
  fi

  run_cmd mkdir -p "$target_dir"

  if [[ -f "$secrets_env" ]]; then
    log_info "Rendering Noctalia config.toml from template + secrets.env -> ${target_cfg}"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      printf '[DRY-RUN] render %s with secrets from %s -> %s (mode 0600)\n' "$template" "$secrets_env" "$target_cfg"
      return 0
    fi
    local hotspot_pw="" wallhaven_key=""
    # shellcheck disable=SC1090
    hotspot_pw="$(set -a; source "$secrets_env"; printf '%s' "${NOCTALIA_HOTSPOT_PASSWORD:-REPLACE_WITH_HOTSPOT_PASSWORD}")"
    # shellcheck disable=SC1090
    wallhaven_key="$(set -a; source "$secrets_env"; printf '%s' "${NOCTALIA_WALLHAVEN_API_KEY:-REPLACE_WITH_WALLHAVEN_API_KEY}")"

    local tmp_cfg
    tmp_cfg="$(mktemp)"
    HOTSPOT_PW="$hotspot_pw" WALLHAVEN_KEY="$wallhaven_key" python3 - "$template" "$tmp_cfg" <<'PY'
import os, sys
src, dst = sys.argv[1], sys.argv[2]
with open(src, "r", encoding="utf-8") as f:
    data = f.read()
data = data.replace("REPLACE_WITH_HOTSPOT_PASSWORD", os.environ["HOTSPOT_PW"])
data = data.replace("REPLACE_WITH_WALLHAVEN_API_KEY", os.environ["WALLHAVEN_KEY"])
with open(dst, "w", encoding="utf-8") as f:
    f.write(data)
PY
    install -m 0600 "$tmp_cfg" "$target_cfg"
    rm -f "$tmp_cfg"
  else
    log_info "No secrets.env found; copying Noctalia template (0600) -> ${target_cfg}"
    run_cmd install -m 0600 "$template" "$target_cfg"
  fi
}

run_stow_for_pkg() {
  local mode_flag="$1"
  local pkg="$2"
  local -a cmd=(stow --no-folding -d "$STOW_DIR" -t "$TARGET_DIR")

  if [[ "$DRY_RUN" -eq 1 || "$ACTION" == "status" ]]; then
    cmd+=(-n -v)
  fi
  if [[ -n "$mode_flag" ]]; then
    cmd+=("$mode_flag")
  fi
  if [[ "$pkg" == "noctalia" ]]; then
    cmd+=(--ignore='config\.toml')
  fi
  cmd+=("$pkg")

  # In dry-run/status mode, run stow -n directly so the user sees stow's output
  if [[ "$DRY_RUN" -eq 1 && "$ACTION" != "status" ]]; then
    printf '[DRY-RUN]'
    printf ' %q' "${cmd[@]}"
    printf '\n'
    "${cmd[@]}" || true
  else
    "${cmd[@]}"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    deploy|undeploy|restow|status)
      ACTION="$1"
      shift
      ;;
    --profile)
      [[ $# -ge 2 ]] || { log_error "--profile requires an argument"; exit 1; }
      PROFILE="$2"
      shift 2
      ;;
    --target)
      [[ $# -ge 2 ]] || { log_error "--target requires an argument"; exit 1; }
      TARGET_DIR="$2"
      shift 2
      ;;
    --backup-dir)
      [[ $# -ge 2 ]] || { log_error "--backup-dir requires an argument"; exit 1; }
      BACKUP_DIR="$2"
      export BACKUP_ROOT="$BACKUP_DIR"
      shift 2
      ;;
    --force-noctalia-render)
      FORCE_NOCTALIA_RENDER=1
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
      log_error "Unknown argument: $1"
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$ACTION" ]]; then
  log_error "Missing action."
  usage >&2
  exit 1
fi

if [[ "$PROFILE" != "active" && "$PROFILE" != "all" ]]; then
  log_error "Invalid profile: ${PROFILE} (expected active or all)"
  exit 1
fi

mapfile -t PACKAGES < <(get_profile_packages)
log_info "Action=${ACTION} Profile=${PROFILE} Packages=${#PACKAGES[@]} Target=${TARGET_DIR}"

case "$ACTION" in
  deploy)
    for pkg in "${PACKAGES[@]}"; do
      run_stow_for_pkg "" "$pkg"
    done
    render_noctalia_config
    ;;
  undeploy)
    for pkg in "${PACKAGES[@]}"; do
      run_stow_for_pkg "-D" "$pkg"
    done
    ;;
  restow)
    for pkg in "${PACKAGES[@]}"; do
      run_stow_for_pkg "-R" "$pkg"
    done
    render_noctalia_config
    ;;
  status)
    for pkg in "${PACKAGES[@]}"; do
      run_stow_for_pkg "" "$pkg"
    done
    ;;
esac

log_info "stow-manage (${ACTION}) completed."
