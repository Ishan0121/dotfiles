#!/usr/bin/env bash
# Install system and AUR packages from categorized manifests.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

DISTRO="auto"
CATEGORY="all"

usage() {
  cat <<'EOF'
Usage: install-packages.sh [OPTIONS]

Install packages from packages/*.txt manifests.

Options:
      --distro <auto|arch|fedora>
          Target distro (default: auto)
      --category <common|arch|fedora|development|desktop|fonts|aur|all>
          Package category to install (default: all)
      --dry-run
          Print install commands without executing them (never invokes sudo)
  -h, --help
          Show this help message and exit
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

install_pacman_manifest() {
  local manifest="$1"
  local -a pkgs=()
  mapfile -t pkgs < <(read_pkg_list "$manifest")
  if [[ ${#pkgs[@]} -eq 0 ]]; then
    log_info "No packages in ${manifest}; skipping."
    return 0
  fi

  local -a cmd=(pacman -S --needed --noconfirm "${pkgs[@]}")
  if [[ "$EUID" -ne 0 ]]; then
    cmd=(sudo "${cmd[@]}")
  fi
  log_info "Installing ${#pkgs[@]} package(s) from $(basename -- "$manifest")..."
  run_cmd "${cmd[@]}"
}

install_aur_manifest() {
  local manifest="$1"
  local -a pkgs=()
  mapfile -t pkgs < <(read_pkg_list "$manifest")
  if [[ ${#pkgs[@]} -eq 0 ]]; then
    log_info "No AUR packages in ${manifest}; skipping."
    return 0
  fi

  local helper=""
  if command -v paru >/dev/null 2>&1; then
    helper="paru"
  elif command -v yay >/dev/null 2>&1; then
    helper="yay"
  elif [[ "$DRY_RUN" -eq 1 ]]; then
    helper="paru"
  else
    log_error "Neither paru nor yay is installed for AUR packages."
    exit 1
  fi

  log_info "Installing ${#pkgs[@]} AUR package(s) with ${helper}..."
  run_cmd "$helper" -S --needed --noconfirm "${pkgs[@]}"
}

install_dnf_manifest() {
  local manifest="$1"
  local -a pkgs=()
  mapfile -t pkgs < <(read_pkg_list "$manifest")
  if [[ ${#pkgs[@]} -eq 0 ]]; then
    log_info "No packages in ${manifest}; skipping."
    return 0
  fi

  local -a cmd=(dnf install -y "${pkgs[@]}")
  if [[ "$EUID" -ne 0 ]]; then
    cmd=(sudo "${cmd[@]}")
  fi
  log_info "Installing ${#pkgs[@]} package(s) from $(basename -- "$manifest")..."
  run_cmd "${cmd[@]}"
}

PKG_DIR="${DOTFILES_ROOT}/packages"

case "$DISTRO" in
  arch)
    case "$CATEGORY" in
      common|arch|development|desktop|fonts)
        install_pacman_manifest "${PKG_DIR}/${CATEGORY}.txt"
        ;;
      aur)
        install_aur_manifest "${PKG_DIR}/aur.txt"
        ;;
      all)
        for cat in common arch development desktop fonts; do
          install_pacman_manifest "${PKG_DIR}/${cat}.txt"
        done
        install_aur_manifest "${PKG_DIR}/aur.txt"
        ;;
      fedora)
        log_warn "Skipping fedora.txt on Arch distro."
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
        install_dnf_manifest "${PKG_DIR}/${CATEGORY}.txt"
        ;;
      all)
        install_dnf_manifest "${PKG_DIR}/fedora.txt"
        ;;
      arch|aur|development|desktop|fonts)
        log_warn "Category '${CATEGORY}' is Arch-specific; use --category fedora on Fedora."
        ;;
      *)
        log_error "Unknown category: ${CATEGORY}"
        exit 1
        ;;
    esac
    ;;
esac

log_info "Package installation step finished."
