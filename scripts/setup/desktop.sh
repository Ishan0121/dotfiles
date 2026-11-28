#!/usr/bin/env bash
# Setup Wayland desktop audio/keyring services, GTK theme/gsettings, and caches.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

TARGET_DIR="$HOME"
THEME_MODE="dark"

usage() {
  cat <<'EOF'
Usage: desktop.sh [OPTIONS]

Configure Wayland desktop user services, XDG user directories, and GTK/font caches:
  - Create XDG user directories without overwriting a stowed user-dirs.dirs symlink
  - Enable pipewire.socket, pipewire-pulse.socket, wireplumber.service,
    gnome-keyring-daemon.socket, and appimagelauncherd.service (if installed)
  - Sync gsettings (adw-gtk3-dark/adw-gtk3, prefer-dark/prefer-light, Bibata cursor)
    and run Noctalia GTK apply.sh if available
  - Refresh fontconfig and desktop application caches

Options:
      --target <dir>         Target home directory (default: $HOME)
      --mode <dark|light>    GTK appearance mode (default: dark)
      --dry-run              Print actions without modifying system state
  -h, --help                 Show this help message and exit
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      [[ $# -ge 2 ]] || { log_error "--target requires an argument"; exit 1; }
      TARGET_DIR="$2"
      shift 2
      ;;
    --mode)
      [[ $# -ge 2 ]] || { log_error "--mode requires an argument"; exit 1; }
      THEME_MODE="$2"
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

case "$THEME_MODE" in
  dark|light) ;;
  *)
    log_error "Invalid --mode value: ${THEME_MODE} (expected dark or light)"
    exit 1
    ;;
esac

log_info "Ensuring XDG user directories exist under ${TARGET_DIR}..."
for sub in Desktop Documents Downloads Music Pictures Public Templates Videos; do
  run_cmd mkdir -p "${TARGET_DIR}/${sub}"
done

if command -v systemctl >/dev/null 2>&1; then
  run_cmd systemctl --user daemon-reload
  for unit in pipewire.socket pipewire-pulse.socket wireplumber.service gnome-keyring-daemon.socket appimagelauncherd.service; do
    if [[ "$DRY_RUN" -eq 1 ]] || systemctl --user list-unit-files "$unit" --no-legend 2>/dev/null | grep -qF "$unit"; then
      log_info "Enabling user unit: ${unit}"
      run_cmd systemctl --user enable --now "$unit"
    fi
  done
fi

if command -v gsettings >/dev/null 2>&1; then
  if [[ "$THEME_MODE" == "dark" ]]; then
    gtk_theme="adw-gtk3-dark"
    color_scheme="prefer-dark"
  else
    gtk_theme="adw-gtk3"
    color_scheme="prefer-light"
  fi
  log_info "Applying gsettings GTK theme (${gtk_theme}, ${color_scheme})..."
  run_cmd gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme"
  run_cmd gsettings set org.gnome.desktop.interface color-scheme "$color_scheme"
  run_cmd gsettings set org.gnome.desktop.interface cursor-theme "Bibata-Modern-Ice"
  run_cmd gsettings set org.gnome.desktop.interface cursor-size 20
  if [[ -d /usr/share/icons/Tela-circle-nord-dark || -d "${HOME}/.local/share/icons/Tela-circle-nord-dark" ]]; then
    run_cmd gsettings set org.gnome.desktop.interface icon-theme "Tela-circle-nord-dark"
  fi
fi

noctalia_gtk_apply="/usr/share/noctalia/assets/templates/gtk/apply.sh"
if [[ -x "$noctalia_gtk_apply" && -f "${HOME}/.config/gtk-3.0/noctalia.css" ]]; then
  log_info "Applying Noctalia GTK CSS (${THEME_MODE})..."
  run_cmd "$noctalia_gtk_apply" "$THEME_MODE"
fi

if command -v fc-cache >/dev/null 2>&1; then
  log_info "Refreshing font cache..."
  run_cmd fc-cache -f
fi

if command -v update-desktop-database >/dev/null 2>&1 && [[ -d "${HOME}/.local/share/applications" ]]; then
  log_info "Refreshing desktop entry database..."
  run_cmd update-desktop-database "${HOME}/.local/share/applications"
fi

log_info "Desktop services & theming setup complete."
