#!/usr/bin/env bash
# Setup Neovim (LazyVim starter + headless plugin sync).

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

TARGET_DIR="$HOME"

usage() {
  cat <<'EOF'
Usage: nvim.sh [OPTIONS]

Ensure LazyVim starter is cloned into ~/.config/nvim (via packages/external.txt)
and run headless Lazy plugin sync.

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

if ! command -v nvim >/dev/null 2>&1; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_warn "nvim is not installed; previewing planned commands."
  else
    log_error "nvim is not installed. Install neovim via packages/common.txt first."
    exit 1
  fi
fi

nvim_dir="${TARGET_DIR}/.config/nvim"
if [[ ! -e "$nvim_dir" ]]; then
  ext_manifest="${DOTFILES_ROOT}/packages/external.txt"
  starter_url="$(awk -F'|' '$1=="lazyvim-starter" {print $3}' "$ext_manifest" 2>/dev/null || true)"
  if [[ -n "$starter_url" ]]; then
    log_info "Cloning lazyvim-starter -> ${nvim_dir}"
    run_cmd mkdir -p "$(dirname -- "$nvim_dir")"
    run_cmd git clone --depth 1 "$starter_url" "$nvim_dir"
  fi
fi

if [[ -f "${nvim_dir}/init.lua" || "$DRY_RUN" -eq 1 ]]; then
  log_info "Syncing LazyVim plugins via headless nvim..."
  run_cmd env HOME="$TARGET_DIR" nvim --headless "+Lazy! sync" +qa
else
  log_warn "${nvim_dir}/init.lua not found; run stow-manage.sh deploy --resolve-conflicts first."
fi

log_info "Neovim setup complete."
