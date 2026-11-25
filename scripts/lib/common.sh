#!/usr/bin/env bash
# Shared helper library for dotfiles management scripts.

# shellcheck disable=SC2034
if [[ -z "${DOTFILES_ROOT:-}" ]]; then
  DOTFILES_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
fi
export DOTFILES_ROOT

# shellcheck disable=SC2034
STOW_DIR="${STOW_DIR:-${DOTFILES_ROOT}/stow}"
export STOW_DIR

# shellcheck disable=SC2034
BACKUP_ROOT="${BACKUP_ROOT:-/mnt/nexus/dotfiles-backups}"
export BACKUP_ROOT

DRY_RUN="${DRY_RUN:-0}"
export DRY_RUN

log_info() {
  printf '[INFO] %s\n' "$*"
}

log_warn() {
  printf '[WARN] %s\n' "$*" >&2
}

log_error() {
  printf '[ERROR] %s\n' "$*" >&2
}

run_cmd() {
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    printf '[DRY-RUN]'
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi
  "$@"
}

detect_distro() {
  local id="" id_like=""
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    id="$(. /etc/os-release && printf '%s' "${ID:-}")"
    # shellcheck disable=SC1091
    id_like="$(. /etc/os-release && printf '%s' "${ID_LIKE:-}")"
  fi

  case "${id,,} ${id_like,,}" in
    *arch*|*garuda*|*endeavouros*|*manjaro*|*cachyos*)
      printf 'arch\n'
      ;;
    *fedora*)
      printf 'fedora\n'
      ;;
    *)
      printf 'unknown\n'
      ;;
  esac
}

read_pkg_list() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    log_error "Package manifest not found: $file"
    return 1
  fi
  sed -e 's/#.*$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$file"
}
