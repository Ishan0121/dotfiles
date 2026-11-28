#!/usr/bin/env bash
# Setup PostgreSQL on Arch/CachyOS following the official Arch Wiki guide.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

DATA_DIR="/var/lib/postgres/data"
SKIP_USER=0

usage() {
  cat <<'EOF'
Usage: postgresql.sh [OPTIONS]

Initialize the PostgreSQL cluster (initdb as postgres user), enable/start
postgresql.service, and create a superuser role for $USER if missing.

Options:
      --skip-user    Do not create a PostgreSQL superuser role for $USER
      --dry-run      Print actions without modifying system state
  -h, --help         Show this help message and exit
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-user)
      SKIP_USER=1
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

if ! command -v postgres >/dev/null 2>&1; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_warn "postgresql is not installed; previewing planned commands."
  else
    log_error "postgresql is not installed. Install it via packages/development.txt first."
    exit 1
  fi
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  log_info "Checking/initializing PostgreSQL cluster at ${DATA_DIR}..."
  run_cmd sudo -iu postgres initdb --locale=C.UTF-8 --encoding=UTF8 -D "$DATA_DIR"
else
  if sudo test -f "${DATA_DIR}/PG_VERSION"; then
    log_info "PostgreSQL data directory already initialized at ${DATA_DIR}."
  else
    log_info "Initializing PostgreSQL data directory at ${DATA_DIR}..."
    run_cmd sudo -iu postgres initdb --locale=C.UTF-8 --encoding=UTF8 -D "$DATA_DIR"
  fi
fi

log_info "Enabling and starting postgresql.service..."
run_cmd sudo systemctl enable --now postgresql.service

if [[ "$SKIP_USER" -eq 0 ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    run_cmd sudo -iu postgres createuser --superuser "$USER"
  else
    if sudo -iu postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${USER}'" 2>/dev/null | grep -q '^1$'; then
      log_info "PostgreSQL role '${USER}' already exists."
    else
      log_info "Creating PostgreSQL superuser role '${USER}'..."
      run_cmd sudo -iu postgres createuser --superuser "$USER"
    fi
  fi
fi

log_info "PostgreSQL setup complete."
