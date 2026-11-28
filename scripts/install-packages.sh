#!/usr/bin/env bash
# Install system and AUR packages from categorized manifests.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

DISTRO="auto"
CATEGORY="all"
YES=0
SELECTOR="${DOTFILES_PKG_SELECTOR:-auto}"

usage() {
  cat <<'EOF'
Usage: install-packages.sh [OPTIONS]

Install packages from packages/*.txt manifests. When run in an interactive
terminal (without --yes), displays an interactive selector allowing individual
package toggles, Select All, and Deselect All (clean skip if 0 selected).

Options:
      --distro <auto|arch|fedora>
          Target distro (default: auto)
      --category <common|arch|fedora|development|desktop|fonts|aur|all>
          Package category to install (default: all)
  -y, --yes, --non-interactive
          Bypass interactive prompt and select all applicable packages
      --dry-run
          Print install commands without executing them (never invokes sudo)
  -h, --help
          Show this help message and exit

Environment:
  DOTFILES_PKG_SELECTOR=auto|bash|fzf|gum|dialog   Override interactive selector
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --distro)
      [[ $# -ge 2 ]] || { log_error "--distro requires an argument"; exit 1; }
      DISTRO="$2"
      shift 2
      ;;
    --category)
      [[ $# -ge 2 ]] || { log_error "--category requires an argument"; exit 1; }
      CATEGORY="$2"
      shift 2
      ;;
    -y|--yes|--non-interactive)
      YES=1
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

if [[ "$DISTRO" == "auto" ]]; then
  DISTRO="$(detect_distro)"
fi

if [[ "$DISTRO" != "arch" && "$DISTRO" != "fedora" ]]; then
  log_error "Unsupported or unrecognized distro: ${DISTRO}"
  exit 1
fi

case "$SELECTOR" in
  auto|bash|fzf|gum|dialog) ;;
  *)
    log_error "Invalid DOTFILES_PKG_SELECTOR: ${SELECTOR} (expected auto, bash, fzf, gum, or dialog)"
    exit 1
    ;;
esac

PKG_DIR="${DOTFILES_ROOT}/packages"

declare -a ALL_PKGS=()
declare -a ALL_CATS=()
declare -a ALL_INSTALLERS=()
declare -A PKG_SEEN=()
declare -A PKG_INSTALLER=()
declare -a SELECTED_PKGS=()
declare -a TMP_FILES=()

cleanup_tmp_files() {
  local f
  for f in "${TMP_FILES[@]}"; do
    [[ -n "$f" ]] && rm -f -- "$f"
  done
}
trap cleanup_tmp_files EXIT
trap 'cleanup_tmp_files; exit 130' INT
trap 'cleanup_tmp_files; exit 143' TERM

add_manifest_packages() {
  local cat_name="$1"
  local installer="$2"
  local manifest="$3"
  local pkg
  local -a manifest_pkgs=()

  mapfile -t manifest_pkgs < <(read_pkg_list "$manifest")
  for pkg in "${manifest_pkgs[@]}"; do
    [[ -z "$pkg" ]] && continue
    if [[ -z "${PKG_SEEN[$pkg]+x}" ]]; then
      PKG_SEEN["$pkg"]=1
      ALL_PKGS+=("$pkg")
      ALL_CATS+=("$cat_name")
      ALL_INSTALLERS+=("$installer")
      PKG_INSTALLER["$pkg"]="$installer"
    fi
  done
}

case "$DISTRO" in
  arch)
    case "$CATEGORY" in
      common|arch|development|desktop|fonts)
        add_manifest_packages "$CATEGORY" "pacman" "${PKG_DIR}/${CATEGORY}.txt"
        ;;
      aur)
        add_manifest_packages "aur" "aur" "${PKG_DIR}/aur.txt"
        ;;
      all)
        for cat in common arch development desktop fonts; do
          add_manifest_packages "$cat" "pacman" "${PKG_DIR}/${cat}.txt"
        done
        add_manifest_packages "aur" "aur" "${PKG_DIR}/aur.txt"
        ;;
      fedora)
        log_warn "Skipping fedora.txt on Arch distro."
        exit 0
        ;;
      *)
        log_error "Unknown category: ${CATEGORY}"
        exit 1
        ;;
    esac
    ;;
  fedora)
    case "$CATEGORY" in
      common|fedora)
        add_manifest_packages "$CATEGORY" "dnf" "${PKG_DIR}/${CATEGORY}.txt"
        ;;
      all)
        add_manifest_packages "fedora" "dnf" "${PKG_DIR}/fedora.txt"
        ;;
      arch|aur|development|desktop|fonts)
        log_warn "Category '${CATEGORY}' is Arch-specific; use --category fedora on Fedora."
        exit 0
        ;;
      *)
        log_error "Unknown category: ${CATEGORY}"
        exit 1
        ;;
    esac
    ;;
esac

if [[ ${#ALL_PKGS[@]} -eq 0 ]]; then
  log_info "No applicable packages found; skipping package installation."
  exit 0
fi

resolve_selector() {
  if [[ "$SELECTOR" == "auto" ]]; then
    if command -v fzf >/dev/null 2>&1; then
      printf 'fzf\n'
    elif command -v gum >/dev/null 2>&1; then
      printf 'gum\n'
    elif command -v dialog >/dev/null 2>&1; then
      printf 'dialog\n'
    else
      printf 'bash\n'
    fi
    return 0
  fi

  if [[ "$SELECTOR" != "bash" ]] && ! command -v "$SELECTOR" >/dev/null 2>&1; then
    log_warn "Requested selector '${SELECTOR}' is not installed; falling back to pure-Bash selector."
    printf 'bash\n'
    return 0
  fi

  printf '%s\n' "$SELECTOR"
}

select_packages_bash() {
  local count=${#ALL_PKGS[@]}
  local -a selected=()
  local i input tok idx num

  for ((i = 0; i < count; i++)); do
    selected[i]=1
  done

  print_pkg_list() {
    local k mark
    printf '\n=== Package Selection (%s / %s: %d package(s)) ===\n' "$DISTRO" "$CATEGORY" "$count"
    for ((k = 0; k < count; k++)); do
      if [[ "${selected[k]}" -eq 1 ]]; then
        mark="x"
      else
        mark=" "
      fi
      printf '  [%3d] [%s] (%-11s | %-6s) %s\n' "$((k + 1))" "$mark" "${ALL_CATS[k]}" "${ALL_INSTALLERS[k]}" "${ALL_PKGS[k]}"
    done
  }

  count_selected() {
    local k c=0
    for ((k = 0; k < count; k++)); do
      if [[ "${selected[k]}" -eq 1 ]]; then
        c=$((c + 1))
      fi
    done
    printf '%d\n' "$c"
  }

  print_pkg_list

  while true; do
    local sel_cnt
    sel_cnt="$(count_selected)"
    printf '\nCommands: <nums/ranges/names> toggle | a all | n none | l list | c/Enter confirm | q skip\n'
    if ! IFS= read -r -p "Selected (${sel_cnt}/${count}) > " input; then
      printf '\n'
      for ((i = 0; i < count; i++)); do
        selected[i]=0
      done
      break
    fi

    # Trim leading/trailing whitespace
    input="${input#"${input%%[![:space:]]*}"}"
    input="${input%"${input##*[![:space:]]}"}"

    case "${input,,}" in
      ""|c|confirm|y|yes)
        break
        ;;
      q|quit|cancel)
        for ((i = 0; i < count; i++)); do
          selected[i]=0
        done
        break
        ;;
      a|all)
        for ((i = 0; i < count; i++)); do
          selected[i]=1
        done
        printf 'Selected all (%d/%d).\n' "$count" "$count"
        ;;
      n|none)
        for ((i = 0; i < count; i++)); do
          selected[i]=0
        done
        printf 'Deselected all (0/%d).\n' "$count"
        ;;
      l|list)
        print_pkg_list
        ;;
      *)
        local normalized
        local -a tokens=()
        normalized="${input//,/ }"
        IFS=' '$'\t' read -r -a tokens <<< "$normalized"
        for tok in "${tokens[@]}"; do
          [[ -z "$tok" ]] && continue
          if [[ "$tok" =~ ^[0-9]+-[0-9]+$ ]]; then
            local start_num end_num r
            start_num=$((10#${tok%-*}))
            end_num=$((10#${tok#*-}))
            if [[ "$start_num" -lt 1 || "$end_num" -gt "$count" || "$start_num" -gt "$end_num" ]]; then
              printf 'Invalid range: %s (valid: 1-%d)\n' "$tok" "$count"
              continue
            fi
            for ((r = start_num; r <= end_num; r++)); do
              idx=$((r - 1))
              selected[idx]=$((1 - selected[idx]))
            done
          elif [[ "$tok" =~ ^[0-9]+$ ]]; then
            num=$((10#$tok))
            if [[ "$num" -lt 1 || "$num" -gt "$count" ]]; then
              printf 'Index out of range: %s (valid: 1-%d)\n' "$tok" "$count"
              continue
            fi
            idx=$((num - 1))
            selected[idx]=$((1 - selected[idx]))
          else
            local found=0
            for ((i = 0; i < count; i++)); do
              if [[ "${ALL_PKGS[i]}" == "$tok" ]]; then
                selected[i]=$((1 - selected[i]))
                found=1
                break
              fi
            done
            if [[ "$found" -eq 0 ]]; then
              printf 'Unknown command or package: %s\n' "$tok"
            fi
          fi
        done
        ;;
    esac
  done

  SELECTED_PKGS=()
  for ((i = 0; i < count; i++)); do
    if [[ "${selected[i]}" -eq 1 ]]; then
      SELECTED_PKGS+=("${ALL_PKGS[i]}")
    fi
  done
}

select_packages_fzf() {
  local count=${#ALL_PKGS[@]}
  local cnt_file=""
  local -a lines=()
  local i rc=0

  cnt_file="$(mktemp)"
  TMP_FILES+=("$cnt_file")
  # Track exact FZF_SELECT_COUNT on Enter so Deselect All + Enter is unambiguous (0 vs 1 cursor item).
  for ((i = 0; i < count; i++)); do
    lines+=("$(printf '%s\t[%s | %s]' "${ALL_PKGS[i]}" "${ALL_CATS[i]}" "${ALL_INSTALLERS[i]}")")
  done

  local fzf_out="" fzf_bind=""
  fzf_bind="start:select-all,ctrl-a:select-all,ctrl-d:deselect-all,enter:execute-silent(printf '%s' \"\$FZF_SELECT_COUNT\" > \"\$DOTFILES_FZF_CNT_FILE\")+accept"
  if ! fzf_out="$(
    printf '%s\n' "${lines[@]}" | DOTFILES_FZF_CNT_FILE="$cnt_file" fzf \
      --multi \
      --sync \
      --layout=reverse \
      --height=80% \
      --border \
      --header='TAB: toggle | Ctrl-A: select all | Ctrl-D: deselect all | ENTER: confirm | ESC: skip all' \
      --bind "$fzf_bind"
  )"; then
    rc=$?
  fi

  local sel_count=""
  if [[ -f "$cnt_file" ]]; then
    sel_count="$(cat -- "$cnt_file")"
    rm -f -- "$cnt_file"
  fi

  if [[ "$rc" -ne 0 || "$sel_count" == "0" ]]; then
    SELECTED_PKGS=()
    return 0
  fi

  SELECTED_PKGS=()
  local line pkg_name
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    pkg_name="${line%%$'\t'*}"
    SELECTED_PKGS+=("$pkg_name")
  done <<< "$fzf_out"
}

select_packages_gum() {
  local count=${#ALL_PKGS[@]}
  local -a lines=()
  local selected_csv=""
  local i rc=0 gum_out=""

  for ((i = 0; i < count; i++)); do
    local entry="${ALL_PKGS[i]} [${ALL_CATS[i]}|${ALL_INSTALLERS[i]}]"
    lines+=("$entry")
    if [[ -z "$selected_csv" ]]; then
      selected_csv="$entry"
    else
      selected_csv="${selected_csv},${entry}"
    fi
  done

  if ! gum_out="$(
    gum choose \
      --no-limit \
      --header="Select packages (${DISTRO}/${CATEGORY}) - Space/x: toggle, a: all/none, Enter: confirm, Esc: skip" \
      --selected="$selected_csv" \
      "${lines[@]}"
  )"; then
    rc=$?
  fi

  if [[ "$rc" -ne 0 ]]; then
    SELECTED_PKGS=()
    return 0
  fi

  SELECTED_PKGS=()
  local line
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    SELECTED_PKGS+=("${line%% *}")
  done <<< "$gum_out"
}

select_packages_dialog() {
  local count=${#ALL_PKGS[@]}
  local -a dialog_args=()
  local i rc=0 tmp_out dialog_out=""

  tmp_out="$(mktemp)"
  TMP_FILES+=("$tmp_out")
  for ((i = 0; i < count; i++)); do
    dialog_args+=("${ALL_PKGS[i]}" "${ALL_CATS[i]} (${ALL_INSTALLERS[i]})" "on")
  done

  if ! dialog --separate-output --checklist \
    "Select packages to install (${DISTRO}/${CATEGORY}). Space=toggle, Enter=confirm, Cancel=skip:" \
    22 76 14 "${dialog_args[@]}" 2>"$tmp_out"; then
    rc=$?
  fi

  if [[ -f "$tmp_out" ]]; then
    dialog_out="$(cat -- "$tmp_out")"
    rm -f -- "$tmp_out"
  fi

  if [[ "$rc" -ne 0 ]]; then
    SELECTED_PKGS=()
    return 0
  fi

  SELECTED_PKGS=()
  local line
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    SELECTED_PKGS+=("$line")
  done <<< "$dialog_out"
}

if [[ "$YES" -eq 0 && -t 0 && -t 1 ]]; then
  active_selector="$(resolve_selector)"
  log_info "Interactive mode (${active_selector}): ${#ALL_PKGS[@]} applicable package(s) for ${DISTRO}/${CATEGORY}."
  case "$active_selector" in
    fzf)
      select_packages_fzf
      ;;
    gum)
      select_packages_gum
      ;;
    dialog)
      select_packages_dialog
      ;;
    bash)
      select_packages_bash
      ;;
  esac
else
  SELECTED_PKGS=("${ALL_PKGS[@]}")
fi

if [[ ${#SELECTED_PKGS[@]} -eq 0 ]]; then
  log_info "No packages selected; skipping package installation."
  exit 0
fi

declare -a PACMAN_PKGS=()
declare -a AUR_PKGS=()
declare -a DNF_PKGS=()

for pkg in "${SELECTED_PKGS[@]}"; do
  case "${PKG_INSTALLER[$pkg]:-}" in
    pacman) PACMAN_PKGS+=("$pkg") ;;
    aur) AUR_PKGS+=("$pkg") ;;
    dnf) DNF_PKGS+=("$pkg") ;;
    *)
      log_warn "Unknown installer mapping for selected package: ${pkg}"
      ;;
  esac
done

resolve_aur_helper() {
  if command -v paru >/dev/null 2>&1; then
    printf 'paru\n'
  elif command -v yay >/dev/null 2>&1; then
    printf 'yay\n'
  elif [[ "$DRY_RUN" -eq 1 ]]; then
    printf 'paru\n'
  else
    return 1
  fi
}

filter_pacman_packages() {
  local helper="" pkg line
  local -A repo_avail=()
  local -A aur_seen=()
  local -a resolved_pacman=()

  command -v pacman >/dev/null 2>&1 || return 0

  while IFS= read -r line; do
    [[ -n "$line" ]] && repo_avail["$line"]=1
  done < <(pacman -Ssq 2>/dev/null || true; pacman -Sg 2>/dev/null || true)

  # Skip pre-filtering if sync databases are not initialized yet.
  if [[ ${#repo_avail[@]} -eq 0 ]]; then
    return 0
  fi

  helper="$(resolve_aur_helper 2>/dev/null || true)"
  for pkg in "${AUR_PKGS[@]}"; do
    aur_seen["$pkg"]=1
  done

  for pkg in "${PACMAN_PKGS[@]}"; do
    if [[ -n "${repo_avail[$pkg]+x}" ]] || pacman -Sp -- "$pkg" >/dev/null 2>&1; then
      resolved_pacman+=("$pkg")
    elif pacman -Qq -- "$pkg" >/dev/null 2>&1; then
      log_info "Package '${pkg}' is not in sync repos but is already installed locally; skipping."
    elif [[ -n "$helper" ]] && "$helper" -Sia -- "$pkg" >/dev/null 2>&1; then
      log_warn "Package '${pkg}' not found in pacman repos; queuing for ${helper}."
      if [[ -z "${aur_seen[$pkg]+x}" ]]; then
        AUR_PKGS+=("$pkg")
        aur_seen["$pkg"]=1
      fi
    else
      log_warn "Package '${pkg}' not found in pacman repos${helper:+ or AUR}; skipping."
    fi
  done

  PACMAN_PKGS=("${resolved_pacman[@]}")
}

filter_aur_packages() {
  local helper="$1"
  local pkg si_err=""
  local -a resolved_aur=()

  if si_err="$("$helper" -Si -- "${AUR_PKGS[@]}" 2>&1 >/dev/null)"; then
    return 0
  fi

  # Only filter individual targets when the helper reports missing package(s),
  # not on transient network/RPC errors.
  case "${si_err,,}" in
    *"not found"*|*"could not find"*)
      for pkg in "${AUR_PKGS[@]}"; do
        if "$helper" -Si -- "$pkg" >/dev/null 2>&1; then
          resolved_aur+=("$pkg")
        else
          log_warn "Package '${pkg}' not found in ${helper} repos or AUR; skipping."
        fi
      done
      AUR_PKGS=("${resolved_aur[@]}")
      ;;
  esac
}

if [[ "$DRY_RUN" -eq 0 && ${#PACMAN_PKGS[@]} -gt 0 ]]; then
  filter_pacman_packages
fi

declare -a confirm_args=()
if [[ "$YES" -eq 1 || ! -t 0 || ! -t 1 ]]; then
  confirm_args+=(--noconfirm)
fi

if [[ ${#PACMAN_PKGS[@]} -gt 0 ]]; then
  cmd=(pacman -S --needed "${confirm_args[@]}" "${PACMAN_PKGS[@]}")
  if [[ "$EUID" -ne 0 ]]; then
    cmd=(sudo "${cmd[@]}")
  fi
  log_info "Installing ${#PACMAN_PKGS[@]} pacman package(s)..."
  run_cmd "${cmd[@]}"
fi

if [[ ${#AUR_PKGS[@]} -gt 0 ]]; then
  helper=""
  if ! helper="$(resolve_aur_helper)"; then
    log_error "Neither paru nor yay is installed for AUR packages."
    exit 1
  fi
  if [[ "$DRY_RUN" -eq 0 ]]; then
    filter_aur_packages "$helper"
  fi
  if [[ ${#AUR_PKGS[@]} -gt 0 ]]; then
    log_info "Installing ${#AUR_PKGS[@]} AUR package(s) with ${helper}..."
    run_cmd "$helper" -S --needed "${confirm_args[@]}" "${AUR_PKGS[@]}"
  fi
fi

if [[ ${#DNF_PKGS[@]} -gt 0 ]]; then
  cmd=(dnf install -y "${DNF_PKGS[@]}")
  if [[ "$EUID" -ne 0 ]]; then
    cmd=(sudo "${cmd[@]}")
  fi
  log_info "Installing ${#DNF_PKGS[@]} dnf package(s)..."
  run_cmd "${cmd[@]}"
fi

log_info "Package installation step finished."
