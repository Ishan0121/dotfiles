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
SKIP_SETUP=0
NO_BACKUP=0
YES=0

usage() {
  cat <<'EOF'
Usage: bootstrap.sh [OPTIONS]

Orchestrate dotfiles bootstrap:
  1. check-deps.sh
  2. backup-restore.sh backup  (unless --no-backup)
  3. install-packages.sh       (interactive on TTY unless --yes or --skip-packages)
  4. setup-externals.sh        (unless --skip-externals)
  5. stow-manage.sh deploy     (--resolve-conflicts; backs up & removes colliding targets)
  6. check-secrets.sh
  7. scripts/setup/*.sh        (interactive per-app prompts on TTY unless --skip-setup or --yes)

Options:
      --profile <active|all>         Stow profile to deploy (default: active)
      --target <dir>                 Target home directory (default: $HOME)
      --backup-dir <dir>             Backup directory (default: /mnt/nexus/dotfiles-backups)
      --skip-packages                Skip system/AUR package installation
      --skip-externals               Skip cloning external git dependencies
      --skip-setup                   Skip interactive per-app setup prompts at the end
      --no-backup                    Skip pre-stow and conflict backups
  -y, --yes, --non-interactive       Accept package installation without prompting (skips per-app setup prompts)
      --dry-run                      Simulate all mutating steps
  -h, --help                         Show this help message and exit
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
    --skip-setup)
      SKIP_SETUP=1
      shift
      ;;
    --no-backup)
      NO_BACKUP=1
      shift
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

dry_args=()
if [[ "$DRY_RUN" -eq 1 ]]; then
  dry_args+=(--dry-run)
fi

pkg_args=()
if [[ "$YES" -eq 1 ]]; then
  pkg_args+=(--yes)
fi

stow_args=(--profile "$PROFILE" --target "$TARGET_DIR" --backup-dir "$BACKUP_DIR" --resolve-conflicts)
if [[ "$NO_BACKUP" -eq 1 ]]; then
  stow_args+=(--no-backup)
else
  DOTFILES_BACKUP_DEST="${BACKUP_DIR}/backup-$(date +%Y%m%d-%H%M%S)"
  export DOTFILES_BACKUP_DEST
fi
if [[ "$DRY_RUN" -eq 1 ]]; then
  stow_args+=(--dry-run)
fi

log_info "Step 1/7: Checking dependencies..."
"${SCRIPT_DIR}/check-deps.sh"

if [[ "$NO_BACKUP" -eq 0 ]]; then
  log_info "Step 2/7: Backing up existing target files..."
  "${SCRIPT_DIR}/backup-restore.sh" backup --target "$TARGET_DIR" --backup-dir "$BACKUP_DIR" "${dry_args[@]}"
else
  log_info "Step 2/7: Skipping backup (--no-backup)."
fi

if [[ "$SKIP_PACKAGES" -eq 0 ]]; then
  log_info "Step 3/7: Installing packages..."
  "${SCRIPT_DIR}/install-packages.sh" "${dry_args[@]}" "${pkg_args[@]}"
else
  log_info "Step 3/7: Skipping package installation (--skip-packages)."
fi

if [[ "$SKIP_EXTERNALS" -eq 0 ]]; then
  log_info "Step 4/7: Setting up external git dependencies..."
  "${SCRIPT_DIR}/setup-externals.sh" --target "$TARGET_DIR" "${dry_args[@]}"
else
  log_info "Step 4/7: Skipping external dependencies (--skip-externals)."
fi

log_info "Step 5/7: Deploying Stow packages (profile: ${PROFILE})..."
"${SCRIPT_DIR}/stow-manage.sh" deploy "${stow_args[@]}"

log_info "Step 6/7: Running secret scan..."
"${SCRIPT_DIR}/check-secrets.sh" --root "$DOTFILES_ROOT"

run_interactive_app_setups() {
  local setup_dir="${SCRIPT_DIR}/setup"
  local entry script_name has_target desc script_path reply
  local -a app_entries=(
    "zsh.sh|1|Zsh, Oh My Zsh, plugins, and default login shell"
    "desktop.sh|1|Wayland audio/keyring services, XDG dirs, GTK theme, and font cache"
    "kitty.sh|1|Kitty themes and configuration check"
    "git.sh|1|Git local identity (~/.gitconfig.local) and SSH key"
    "nvim.sh|1|Neovim LazyVim starter and headless plugin sync"
    "vscode.sh|0|VS Code extensions"
    "antigravity.sh|0|Antigravity IDE extensions"
    "voxtype.sh|1|Voxtype Whisper (base.en), input group, and voxtype.service"
    "mpd.sh|1|MPD directories, mpd.service, and mpd-mpris.service"
    "ydotool.sh|0|ydotool uinput access and ydotool.service"
    "noctalia-greeter.sh|0|Noctalia Greeter + greetd login manager"
    "docker.sh|0|Docker daemon and docker group"
    "podman.sh|0|Rootless Podman subuid/subgid and podman.socket"
    "rust.sh|0|Rustup default stable toolchain and components"
    "postgresql.sh|0|PostgreSQL cluster init, service, and user role"
    "virt.sh|0|Libvirt daemon, libvirt group, and default NAT network"
    "tailscale.sh|0|Tailscale daemon (tailscaled.service)"
    "ufw.sh|0|UFW firewall defaults and ufw.service"
    "bluetooth.sh|0|Bluetooth service (bluetooth.service)"
    "snapper.sh|0|Snapper root config and snapshot cleanup timer"
    "paccache.sh|0|Pacman cache cleanup (paccache.timer) and fstrim.timer"
  )
  local -a run_args=()

  log_info "Step 7/7: Per-app setup (asks before running each script)..."
  for entry in "${app_entries[@]}"; do
    IFS='|' read -r script_name has_target desc <<< "$entry"
    script_path="${setup_dir}/${script_name}"
    [[ -x "$script_path" ]] || continue

    while true; do
      if ! IFS= read -r -p "Set up ${script_name%.sh} (${desc})? [y/N/q] " reply; then
        printf '\n'
        return 0
      fi
      reply="${reply#"${reply%%[![:space:]]*}"}"
      reply="${reply%"${reply##*[![:space:]]}"}"
      case "${reply,,}" in
        y|yes)
          run_args=()
          if [[ "$has_target" -eq 1 ]]; then
            run_args+=(--target "$TARGET_DIR")
          fi
          if [[ "$DRY_RUN" -eq 1 ]]; then
            run_args+=(--dry-run)
          fi
          if ! "$script_path" "${run_args[@]}"; then
            log_warn "Setup script ${script_name} exited non-zero; continuing."
          fi
          break
          ;;
        ""|n|no)
          log_info "Skipped ${script_name%.sh}."
          break
          ;;
        q|quit)
          log_info "Stopped per-app setup prompts; run scripts/setup/<app>.sh individually anytime."
          return 0
          ;;
        *)
          printf 'Please answer y (yes), n (no), or q (quit remaining prompts).\n'
          ;;
      esac
    done
  done
}

if [[ "$SKIP_SETUP" -eq 1 ]]; then
  log_info "Step 7/7: Skipping per-app setup prompts (--skip-setup)."
elif [[ "$YES" -eq 1 || ! -t 0 || ! -t 1 ]]; then
  log_info "Step 7/7: Skipping interactive per-app setup prompts (non-interactive/--yes); run scripts/setup/<app>.sh individually as needed."
else
  run_interactive_app_setups
fi

log_info "Bootstrap complete!"
