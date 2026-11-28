#!/usr/bin/env bash
# Setup Kitty terminal themes (kitty-themes clone and font/config check).

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

TARGET_DIR="$HOME"

usage() {
  cat <<'EOF'
Usage: kitty.sh [OPTIONS]

Ensure kitty-themes from packages/external.txt is cloned and verify Kitty's
stowed configuration and theme symlinks.

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

if ! command -v kitty >/dev/null 2>&1; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_warn "kitty is not installed; previewing planned commands."
  else
    log_error "kitty is not installed. Install it via packages/desktop.txt first."
    exit 1
  fi
fi

themes_dir="${TARGET_DIR}/.config/kitty/kitty-themes"
if [[ -e "$themes_dir" ]]; then
  log_info "kitty-themes already exists at ${themes_dir}."
else
  ext_manifest="${DOTFILES_ROOT}/packages/external.txt"
  themes_url="$(awk -F'|' '$1=="kitty-themes" {print $3}' "$ext_manifest" 2>/dev/null || true)"
  if [[ -n "$themes_url" ]]; then
    log_info "Cloning kitty-themes -> ${themes_dir}"
    run_cmd mkdir -p "$(dirname -- "$themes_dir")"
    run_cmd git clone --depth 1 "$themes_url" "$themes_dir"
  fi
fi

if [[ ! -f "${TARGET_DIR}/.config/kitty/kitty.conf" ]]; then
  log_warn "${TARGET_DIR}/.config/kitty/kitty.conf not found; run stow-manage.sh deploy first."
fi

log_info "Kitty setup complete."
