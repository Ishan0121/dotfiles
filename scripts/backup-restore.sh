#!/usr/bin/env bash
# Backup and restore $HOME targets before/after Stow operations.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

TARGET_DIR="$HOME"
BACKUP_DIR="$BACKUP_ROOT"

usage() {
  cat <<'EOF'
Usage: backup-restore.sh <ACTION> [OPTIONS]

Actions:
  backup              Backup existing target files/dirs that collide with stow/
  restore <dir>       Restore files from a backup directory into target
  list                List available backups in backup directory

Options:
      --target <dir>      Target home directory (default: $HOME)
      --backup-dir <dir>  Backup root directory (default: /mnt/nexus/dotfiles-backups)
      --dry-run           Print actions without modifying files
  -h, --help              Show this help message and exit
EOF
}

collect_stow_relpaths() {
  local pkg_dir
  for pkg_dir in "${STOW_DIR}"/*; do
    [[ -d "$pkg_dir" ]] || continue
    (
      cd -- "$pkg_dir"
      find . -mindepth 1 \( -type f -o -type l \) -print | sed 's|^\./||'
    )
  done | sort -u
}

is_stow_owned_dir_symlink() {
  local link_path="$1"
  local rel_sub="$2"
  local link_raw target_base_canon stow_base_canon rel_dir target_parent_canon expected_rel pkg_dir

  link_raw="$(readlink -- "$link_path" 2>/dev/null || true)"
  [[ -n "$link_raw" && "$link_raw" != /* ]] || return 1

  target_base_canon="$(realpath -m -- "$TARGET_DIR")"
  stow_base_canon="$(realpath -m -- "$STOW_DIR")"
  rel_dir="$(dirname -- "$rel_sub")"
  if [[ "$rel_dir" == "." ]]; then
    target_parent_canon="$target_base_canon"
  else
    target_parent_canon="${target_base_canon}/${rel_dir}"
  fi

  for pkg_dir in "${stow_base_canon}"/*; do
    [[ -d "${pkg_dir}/${rel_sub}" ]] || continue
    expected_rel="$(realpath -m -s --relative-to="$target_parent_canon" -- "${pkg_dir}/${rel_sub}")"
    if [[ "$link_raw" == "$expected_rel" ]]; then
      return 0
    fi
  done
  return 1
}

do_backup() {
  local timestamp dest rel src dst_parent count=0
  local dir_part part sub p ancestor_symlink
  local -a parts=()
  local -A backed_up_ancestors=()

  timestamp="$(date +%Y%m%d-%H%M%S)"
  dest="${DOTFILES_BACKUP_DEST:-${BACKUP_DIR}/backup-${timestamp}}"

  log_info "Checking ${TARGET_DIR} for colliding target files -> ${dest}"

  while IFS= read -r rel; do
    [[ -z "$rel" ]] && continue

    # Walk parent components first so a symlinked ancestor directory (e.g. ~/.config/kitty -> foreign_dir)
    # is backed up as the symlink itself without dereferencing into a partial real directory.
    ancestor_symlink=0
    dir_part="$(dirname -- "$rel")"
    if [[ "$dir_part" != "." ]]; then
      IFS='/' read -r -a parts <<< "$dir_part"
      sub=""
      for part in "${parts[@]}"; do
        [[ -z "$part" ]] && continue
        if [[ -z "$sub" ]]; then
          sub="$part"
        else
          sub="${sub}/${part}"
        fi
        p="${TARGET_DIR}/${sub}"
        if [[ -L "$p" ]]; then
          ancestor_symlink=1
          if [[ -z "${backed_up_ancestors[$sub]+x}" ]]; then
            backed_up_ancestors["$sub"]=1
            if ! is_stow_owned_dir_symlink "$p" "$sub"; then
              if [[ ! -e "${dest}/${sub}" && ! -L "${dest}/${sub}" ]]; then
                if [[ "$count" -eq 0 ]]; then
                  run_cmd mkdir -p -- "$dest"
                fi
                dst_parent="$(dirname -- "${dest}/${sub}")"
                run_cmd mkdir -p -- "$dst_parent"
                run_cmd cp -aP -- "$p" "${dest}/${sub}"
                count=$((count + 1))
              fi
            fi
          fi
          break
        fi
      done
    fi
    if [[ "$ancestor_symlink" -eq 1 ]]; then
      continue
    fi

    src="${TARGET_DIR}/${rel}"
    if [[ -e "$src" && ! -L "$src" ]]; then
      if [[ "$count" -eq 0 ]]; then
        run_cmd mkdir -p -- "$dest"
      fi
      dst_parent="$(dirname -- "${dest}/${rel}")"
      run_cmd mkdir -p -- "$dst_parent"
      run_cmd cp -a -- "$src" "${dest}/${rel}"
      count=$((count + 1))
    fi
  done < <(collect_stow_relpaths)

  if [[ "$count" -eq 0 ]]; then
    log_info "Backup complete (0 item(s)); no empty backup directory created."
  else
    log_info "Backup complete (${count} item(s)) at ${dest}"
  fi
}

do_restore() {
  local src_dir="${1:-}"
  if [[ -z "$src_dir" ]]; then
    log_error "restore requires a backup directory argument."
    exit 1
  fi
  if [[ ! -d "$src_dir" ]]; then
    log_error "Backup directory does not exist: $src_dir"
    exit 1
  fi

  log_info "Restoring from ${src_dir} -> ${TARGET_DIR}"
  run_cmd rsync -a "${src_dir}/" "${TARGET_DIR}/"
  log_info "Restore complete."
}

do_list() {
  if [[ ! -d "$BACKUP_DIR" ]]; then
    log_info "No backup directory found at ${BACKUP_DIR}"
    return 0
  fi
  log_info "Backups in ${BACKUP_DIR}:"
  find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d | sort
}

ACTION=""
RESTORE_SRC=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    backup|list)
      ACTION="$1"
      shift
      ;;
    restore)
      ACTION="restore"
      if [[ $# -ge 2 && "$2" != -* ]]; then
        RESTORE_SRC="$2"
        shift 2
      else
        shift
      fi
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

case "$ACTION" in
  backup)
    do_backup
    ;;
  restore)
    do_restore "$RESTORE_SRC"
    ;;
  list)
    do_list
    ;;
  *)
    log_error "Missing or invalid action."
    usage >&2
    exit 1
    ;;
esac
