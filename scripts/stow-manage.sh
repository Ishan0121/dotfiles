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
RESOLVE_CONFLICTS=0
NO_BACKUP=0
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
      --backup-dir <dir>         Backup directory (default: /mnt/nexus/dotfiles-backups)
      --resolve-conflicts        Back up (unless --no-backup) and remove colliding targets
                                 before deploying or restowing
      --no-backup                Skip backing up colliding targets when --resolve-conflicts is set
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

declare -A RESOLVED_CONFLICT_PATHS=()
CONFLICT_BACKUP_DIR=""
CONFLICT_BACKUP_CREATED=0
CONFLICTS_HANDLED=0

backup_and_remove_conflict() {
  local rel="$1"
  local target="$2"
  local reason="$3"

  if [[ -n "${RESOLVED_CONFLICT_PATHS[$rel]+x}" ]]; then
    return 0
  fi
  RESOLVED_CONFLICT_PATHS["$rel"]=1
  CONFLICTS_HANDLED=$((CONFLICTS_HANDLED + 1))

  log_warn "Stow conflict (${reason}): ${target}"
  if [[ "$NO_BACKUP" -eq 0 ]]; then
    local backup_item="${CONFLICT_BACKUP_DIR}/${rel}"
    if [[ ! -e "$backup_item" && ! -L "$backup_item" ]]; then
      if [[ "$CONFLICT_BACKUP_CREATED" -eq 0 ]]; then
        run_cmd mkdir -p -- "$CONFLICT_BACKUP_DIR"
        CONFLICT_BACKUP_CREATED=1
      fi
      run_cmd mkdir -p -- "$(dirname -- "$backup_item")"
      run_cmd cp -aP -- "$target" "$backup_item"
    fi
  fi

  if [[ -d "$target" && ! -L "$target" ]]; then
    run_cmd rm -rf -- "$target"
  else
    run_cmd rm -f -- "$target"
  fi
}

compute_expected_stow_link() {
  local rel="$1"
  local pkg_subpath="$2"
  local target_base_canon stow_base_canon rel_dir target_parent_canon

  target_base_canon="$(realpath -m -- "$TARGET_DIR")"
  stow_base_canon="$(realpath -m -- "$STOW_DIR")"
  rel_dir="$(dirname -- "$rel")"
  if [[ "$rel_dir" == "." ]]; then
    target_parent_canon="$target_base_canon"
  else
    target_parent_canon="${target_base_canon}/${rel_dir}"
  fi
  realpath -m -s --relative-to="$target_parent_canon" -- "${stow_base_canon}/${pkg_subpath}"
}

is_stow_owned_leaf_symlink() {
  local target="$1"
  local pkg="$2"
  local rel="$3"
  local link_raw expected_rel

  link_raw="$(readlink -- "$target" 2>/dev/null || true)"
  [[ -n "$link_raw" && "$link_raw" != /* ]] || return 1
  expected_rel="$(compute_expected_stow_link "$rel" "${pkg}/${rel}")"
  [[ "$link_raw" == "$expected_rel" ]]
}

is_stow_owned_parent_symlink() {
  local p="$1"
  local sub="$2"
  local link_raw expected_rel candidate_pkg

  link_raw="$(readlink -- "$p" 2>/dev/null || true)"
  [[ -n "$link_raw" && "$link_raw" != /* ]] || return 1
  for candidate_pkg in "${PACKAGES[@]}"; do
    [[ -d "${STOW_DIR}/${candidate_pkg}/${sub}" ]] || continue
    expected_rel="$(compute_expected_stow_link "$sub" "${candidate_pkg}/${sub}")"
    if [[ "$link_raw" == "$expected_rel" ]]; then
      return 0
    fi
  done
  return 1
}

resolve_conflicts() {
  local pkg pkg_dir src_path rel dir_part part sub p target skip_leaf
  local -a parts=()
  local timestamp

  timestamp="$(date +%Y%m%d-%H%M%S)"
  CONFLICT_BACKUP_DIR="${DOTFILES_BACKUP_DEST:-${BACKUP_DIR}/backup-${timestamp}}"
  CONFLICT_BACKUP_CREATED=0
  CONFLICTS_HANDLED=0
  RESOLVED_CONFLICT_PATHS=()

  for pkg in "${PACKAGES[@]}"; do
    pkg_dir="${STOW_DIR}/${pkg}"
    [[ -d "$pkg_dir" ]] || continue

    while IFS= read -r -d '' src_path; do
      rel="${src_path#"${pkg_dir}/"}"
      [[ -z "$rel" ]] && continue

      # Noctalia config.toml is ignored by stow and managed by render_noctalia_config
      if [[ "$pkg" == "noctalia" && "$rel" == ".config/noctalia/config.toml" ]]; then
        continue
      fi

      # Check intermediate parent directories for non-directory blockers or foreign/absolute symlinks
      skip_leaf=0
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
          if [[ -e "$p" || -L "$p" ]]; then
            if [[ ! -d "$p" || -L "$p" ]]; then
              if [[ -L "$p" ]] && is_stow_owned_parent_symlink "$p" "$sub"; then
                skip_leaf=1
                break
              fi
              backup_and_remove_conflict "$sub" "$p" "non-directory parent blocking ${rel}"
              skip_leaf=1
              break
            fi
          fi
        done
      fi
      if [[ "$skip_leaf" -eq 1 ]]; then
        continue
      fi

      # Check leaf target path
      target="${TARGET_DIR}/${rel}"
      if [[ ! -e "$target" && ! -L "$target" ]]; then
        continue
      fi

      if [[ -L "$target" ]]; then
        if is_stow_owned_leaf_symlink "$target" "$pkg" "$rel"; then
          continue
        fi
        backup_and_remove_conflict "$rel" "$target" "foreign or non-stow symlink"
      else
        backup_and_remove_conflict "$rel" "$target" "existing non-symlink target"
      fi
    done < <(find "$pkg_dir" -mindepth 1 \( -type f -o -type l \) -print0)
  done

  if [[ "$CONFLICTS_HANDLED" -eq 0 ]]; then
    log_info "Pre-stow conflict check: 0 conflicts found."
  else
    log_info "Pre-stow conflict resolution handled ${CONFLICTS_HANDLED} conflict(s)."
  fi
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
    --resolve-conflicts)
      RESOLVE_CONFLICTS=1
      shift
      ;;
    --no-backup)
      NO_BACKUP=1
      shift
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
    if [[ "$RESOLVE_CONFLICTS" -eq 1 ]]; then
      resolve_conflicts
    fi
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
    if [[ "$RESOLVE_CONFLICTS" -eq 1 ]]; then
      resolve_conflicts
    fi
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
