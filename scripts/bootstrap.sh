#!/usr/bin/env bash
# End-to-end bootstrap orchestrator for dotfiles setup.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

PROFILE="active"
TARGET_DIR="$HOME"
BACKUP_DIR="$BACKUP_ROOT"
SKIP_PACKAGES=0
SKIP_EXTERNALS=0
NO_BACKUP=0

usage() {
  cat <<'EOF'
Usage: bootstrap.sh [OPTIONS]

Orchestrate dotfiles bootstrap:
  1. check-deps.sh
  2. backup-restore.sh backup  (unless --no-backup)
  3. install-packages.sh       (unless --skip-packages)
  4. setup-externals.sh        (unless --skip-externals)
  5. stow-manage.sh deploy
  6. check-secrets.sh

Options:
      --profile <active|all>    Stow profile to deploy (default: active)
      --target <dir>            Target home directory (default: $HOME)
      --backup-dir <dir>        Backup directory (default: /mnt/nexus/dotfiles-backups)
      --skip-packages           Skip system/AUR package installation
      --skip-externals          Skip cloning external git dependencies
      --no-backup               Skip pre-stow backup
      --dry-run                 Simulate all mutating steps
  -h, --help                    Show this help message and exit
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
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
      shift 2
      ;;
    --skip-packages)
      SKIP_PACKAGES=1
      shift
      ;;
    --skip-externals)
      SKIP_EXTERNALS=1
      shift
      ;;
    --no-backup)
      NO_BACKUP=1
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

dry_args=()
if [[ "$DRY_RUN" -eq 1 ]]; then
  dry_args+=(--dry-run)
fi

log_info "Step 1/6: Checking dependencies..."
"${SCRIPT_DIR}/check-deps.sh"

if [[ "$NO_BACKUP" -eq 0 ]]; then
  log_info "Step 2/6: Backing up existing target files..."
  "${SCRIPT_DIR}/backup-restore.sh" backup --target "$TARGET_DIR" --backup-dir "$BACKUP_DIR" "${dry_args[@]}"
else
  log_info "Step 2/6: Skipping backup (--no-backup)."
fi

if [[ "$SKIP_PACKAGES" -eq 0 ]]; then
  log_info "Step 3/6: Installing packages..."
  "${SCRIPT_DIR}/install-packages.sh" "${dry_args[@]}"
else
  log_info "Step 3/6: Skipping package installation (--skip-packages)."
fi

if [[ "$SKIP_EXTERNALS" -eq 0 ]]; then
  log_info "Step 4/6: Setting up external git dependencies..."
  "${SCRIPT_DIR}/setup-externals.sh" --target "$TARGET_DIR" "${dry_args[@]}"
else
  log_info "Step 4/6: Skipping external dependencies (--skip-externals)."
fi

log_info "Step 5/6: Deploying Stow packages (profile: ${PROFILE})..."
"${SCRIPT_DIR}/stow-manage.sh" deploy --profile "$PROFILE" --target "$TARGET_DIR" --backup-dir "$BACKUP_DIR" "${dry_args[@]}"

log_info "Step 6/6: Running secret scan..."
"${SCRIPT_DIR}/check-secrets.sh" --root "$DOTFILES_ROOT"

log_info "Bootstrap complete!"
