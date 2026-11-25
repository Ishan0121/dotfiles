#!/usr/bin/env bash
# Idempotently clone external non-pacman git dependencies (OMZ, plugins, kitty-themes, LazyVim).

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

TARGET_DIR="$HOME"
MANIFEST="${DOTFILES_ROOT}/packages/external.txt"

usage() {
  cat <<'EOF'
Usage: setup-externals.sh [OPTIONS]

Idempotently clone external git repositories listed in packages/external.txt
(Oh My Zsh, custom zsh plugins, kitty-themes, LazyVim/starter). Existing target
directories are left untouched.

Options:
      --target <dir>    Target home directory (default: $HOME)
      --dry-run         Print clone commands without executing them
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

if [[ ! -f "$MANIFEST" ]]; then
  log_error "External manifest not found: ${MANIFEST}"
  exit 1
fi

while IFS='|' read -r name relpath url; do
  [[ -z "$name" || "$name" =~ ^[[:space:]]*# ]] && continue
  dest="${TARGET_DIR}/${relpath}"
  if [[ -e "$dest" ]]; then
    log_info "[SKIP] ${name} already exists at ${dest}"
    continue
  fi
  run_cmd mkdir -p "$(dirname -- "$dest")"
  log_info "Cloning ${name} -> ${dest}"
  run_cmd git clone --depth 1 "$url" "$dest"
done < <(sed -e 's/#.*$//' -e '/^[[:space:]]*$/d' "$MANIFEST")

log_info "External dependencies setup complete."
