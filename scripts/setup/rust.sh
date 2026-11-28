#!/usr/bin/env bash
# Setup Rustup default stable toolchain and standard developer components.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

TOOLCHAIN="stable"

usage() {
  cat <<'EOF'
Usage: rust.sh [OPTIONS]

Configure Rustup's default toolchain (default: stable) and install standard
components (clippy, rustfmt, rust-analyzer) per official Rustup/Arch Wiki docs.

Options:
      --toolchain <name>    Toolchain to install/set default (default: stable)
      --dry-run             Print actions without modifying system state
  -h, --help                Show this help message and exit
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --toolchain)
      [[ $# -ge 2 ]] || { log_error "--toolchain requires an argument"; exit 1; }
      TOOLCHAIN="$2"
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

if ! command -v rustup >/dev/null 2>&1; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_warn "rustup is not installed; previewing planned commands."
  else
    log_error "rustup is not installed. Install it via packages/development.txt first."
    exit 1
  fi
fi

if [[ "$DRY_RUN" -eq 0 ]] && rustup toolchain list 2>/dev/null | grep -q '(default)'; then
  log_info "Rustup default toolchain is already configured."
else
  log_info "Setting Rustup default toolchain to '${TOOLCHAIN}'..."
  run_cmd rustup default "$TOOLCHAIN"
fi

log_info "Ensuring clippy, rustfmt, and rust-analyzer components are installed..."
run_cmd rustup component add clippy rustfmt rust-analyzer

log_info "Rust setup complete."
