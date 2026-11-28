#!/usr/bin/env bash
# Setup Git local identity (~/.gitconfig.local), SSH key, and GitHub CLI check.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

TARGET_DIR="$HOME"
GIT_NAME=""
GIT_EMAIL=""
SKIP_SSH=0

usage() {
  cat <<'EOF'
Usage: git.sh [OPTIONS]

Configure machine-local Git identity (~/.gitconfig.local included by
stow/git/.gitconfig), ensure an Ed25519 SSH key exists, and check gh auth.

Options:
      --target <dir>      Target home directory (default: $HOME)
      --name <name>       User name to write into ~/.gitconfig.local
      --email <email>     User email to write into ~/.gitconfig.local
      --skip-ssh          Skip generating ~/.ssh/id_ed25519 if missing
      --dry-run           Print actions without modifying system state
  -h, --help              Show this help message and exit
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      [[ $# -ge 2 ]] || { log_error "--target requires an argument"; exit 1; }
      TARGET_DIR="$2"
      shift 2
      ;;
    --name)
      [[ $# -ge 2 ]] || { log_error "--name requires an argument"; exit 1; }
      GIT_NAME="$2"
      shift 2
      ;;
    --email)
      [[ $# -ge 2 ]] || { log_error "--email requires an argument"; exit 1; }
      GIT_EMAIL="$2"
      shift 2
      ;;
    --skip-ssh)
      SKIP_SSH=1
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

if ! command -v git >/dev/null 2>&1; then
  log_error "git is not installed."
  exit 1
fi

local_cfg="${TARGET_DIR}/.gitconfig.local"
if [[ -n "$GIT_NAME" || -n "$GIT_EMAIL" ]]; then
  if [[ -n "$GIT_NAME" ]]; then
    run_cmd git config --file "$local_cfg" user.name "$GIT_NAME"
  fi
  if [[ -n "$GIT_EMAIL" ]]; then
    run_cmd git config --file "$local_cfg" user.email "$GIT_EMAIL"
  fi
elif [[ ! -f "$local_cfg" ]]; then
  existing_name="$(git config --global user.name 2>/dev/null || true)"
  existing_email="$(git config --global user.email 2>/dev/null || true)"
  if [[ -n "$existing_name" && -n "$existing_email" ]]; then
    log_info "Creating ${local_cfg} from existing Git identity (${existing_name} <${existing_email}>)..."
    run_cmd git config --file "$local_cfg" user.name "$existing_name"
    run_cmd git config --file "$local_cfg" user.email "$existing_email"
  else
    log_warn "${local_cfg} not found; pass --name and --email to configure machine-local Git identity."
  fi
else
  log_info "Machine-local Git config already exists: ${local_cfg}"
fi

if [[ "$SKIP_SSH" -eq 0 ]]; then
  ssh_dir="${TARGET_DIR}/.ssh"
  key_file="${ssh_dir}/id_ed25519"
  if [[ -f "$key_file" || -f "${ssh_dir}/id_rsa" ]]; then
    log_info "SSH key already exists in ${ssh_dir}."
  elif command -v ssh-keygen >/dev/null 2>&1; then
    comment="${GIT_EMAIL:-$(git config --global user.email 2>/dev/null || printf '%s@%s' "$USER" "$(hostname)")}"
    log_info "Generating Ed25519 SSH key at ${key_file}..."
    run_cmd mkdir -p "$ssh_dir"
    run_cmd chmod 0700 "$ssh_dir"
    run_cmd ssh-keygen -t ed25519 -C "$comment" -f "$key_file" -N ""
  else
    log_warn "ssh-keygen not found; skipping SSH key generation."
  fi
fi

if [[ "$DRY_RUN" -eq 0 ]] && command -v gh >/dev/null 2>&1; then
  if ! gh auth status >/dev/null 2>&1; then
    log_warn "GitHub CLI (gh) is not authenticated. Run 'gh auth login' when ready."
  else
    log_info "GitHub CLI (gh) is authenticated."
  fi
fi

log_info "Git setup complete."
