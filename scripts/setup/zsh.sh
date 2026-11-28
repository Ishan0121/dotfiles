#!/usr/bin/env bash
# Setup Zsh, Oh My Zsh, custom plugins, completion cache, and default login shell.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

TARGET_DIR="$HOME"
SKIP_CHSH=0

usage() {
  cat <<'EOF'
Usage: zsh.sh [OPTIONS]

Configure Zsh according to Zsh & Oh My Zsh docs:
  - Ensure Oh My Zsh and custom plugins (zsh-autosuggestions, zsh-completions,
    zsh-syntax-highlighting) from packages/external.txt are cloned
  - Ensure ~/.zshrc exists (warn if stowed symlink not deployed yet) and ~/.zsh_history exists
  - Rebuild Zsh completion cache (~/.zcompdump*)
  - Switch the current user's default login shell to zsh (chsh, unless --skip-chsh)

Options:
      --target <dir>    Target home directory (default: $HOME)
      --skip-chsh       Skip changing the login shell to zsh
      --dry-run         Print actions without modifying system state
  -h, --help            Show this help message and exit
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      [[ $# -ge 2 ]] || { log_error "--target requires an argument"; exit 1; }
      TARGET_DIR="$2"
      shift 2
      ;;
    --skip-chsh)
      SKIP_CHSH=1
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

zsh_path="$(command -v zsh || true)"
if [[ -z "$zsh_path" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    zsh_path="/usr/bin/zsh"
    log_warn "zsh is not installed; previewing planned commands."
  else
    log_error "zsh is not installed. Install it via packages/common.txt first."
    exit 1
  fi
fi

ext_manifest="${DOTFILES_ROOT}/packages/external.txt"
if [[ -f "$ext_manifest" ]]; then
  while IFS='|' read -r name relpath url; do
    case "$name" in
      oh-my-zsh|zsh-autosuggestions|zsh-completions|zsh-syntax-highlighting)
        dest="${TARGET_DIR}/${relpath}"
        if [[ -e "$dest" ]]; then
          log_info "[SKIP] ${name} already exists at ${dest}"
        else
          run_cmd mkdir -p "$(dirname -- "$dest")"
          log_info "Cloning ${name} -> ${dest}"
          run_cmd git clone --depth 1 "$url" "$dest"
        fi
        ;;
    esac
  done < <(sed -e 's/#.*$//' -e '/^[[:space:]]*$/d' "$ext_manifest")
fi

if [[ ! -f "${TARGET_DIR}/.zshrc" ]]; then
  log_warn "${TARGET_DIR}/.zshrc not found; run stow-manage.sh deploy first."
fi

if [[ ! -f "${TARGET_DIR}/.zsh_history" ]]; then
  log_info "Initializing ${TARGET_DIR}/.zsh_history..."
  run_cmd touch "${TARGET_DIR}/.zsh_history"
fi

if [[ "$DRY_RUN" -eq 0 && -f "${TARGET_DIR}/.zshrc" ]]; then
  log_info "Refreshing Zsh completion cache..."
  rm -f "${TARGET_DIR}"/.zcompdump* 2>/dev/null || true
  HOME="$TARGET_DIR" "$zsh_path" -fc 'autoload -Uz compinit && compinit -u -d "${ZDOTDIR:-$HOME}/.zcompdump"'
elif [[ "$DRY_RUN" -eq 1 ]]; then
  printf '[DRY-RUN] refresh Zsh compinit cache in %s\n' "$TARGET_DIR"
fi

if [[ "$SKIP_CHSH" -eq 0 ]]; then
  current_shell="$(getent passwd "$USER" 2>/dev/null | cut -d: -f7 || true)"
  if [[ "$current_shell" == "$zsh_path" ]]; then
    log_info "Login shell for '${USER}' is already ${zsh_path}."
  else
    if [[ -r /etc/shells ]] && ! grep -qxF "$zsh_path" /etc/shells; then
      log_info "Adding ${zsh_path} to /etc/shells..."
      if [[ "$DRY_RUN" -eq 1 ]]; then
        printf '[DRY-RUN] append %s to /etc/shells\n' "$zsh_path"
      else
        printf '%s\n' "$zsh_path" | sudo tee -a /etc/shells >/dev/null
      fi
    fi
    log_info "Changing login shell for '${USER}' to ${zsh_path}..."
    run_cmd chsh -s "$zsh_path"
    log_warn "Log out and back in (or open a new login shell) for the default shell change to take effect."
  fi
fi

log_info "Zsh setup complete."
