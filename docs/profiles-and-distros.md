# Profiles and Distros

## Compositor & Shell Profiles

`scripts/stow-manage.sh` and `scripts/bootstrap.sh` support two Stow profiles via `--profile <active|all>`:

### `active` Profile (Default — 20 Packages)

Deploys the primary desktop stack and all core shell, terminal, CLI, theming, and IDE configs:
- **Compositor**: `umbriel` (`~/.config/umbriel/{config.toml,effects/,outputs.toml.example}`)
- **Shell**: `noctalia` (`~/.config/noctalia/secrets.env.example` stowed; `config.toml` rendered locally as `0600`)
- **Core & Desktop**: `zsh`, `bash`, `git`, `starship`, `kitty`, `alacritty`, `foot`, `cli`, `media`, `bin`, `xdg`, `gtk`, `qt`, `desktop-extras`, `nvim`, `vscode`, `antigravity`, `zed`

### `all` Profile (22 Packages)

Includes everything in `active` plus the two optional Wayland compositor configs:
- `hypr` (`~/.config/hypr/`) — Hyprland session configuration
- `niri` (`~/.config/niri/`) — Niri scrollable-tiling compositor configuration

You can also deploy an optional package individually with Stow if needed:

```bash
stow --no-folding -d /mnt/nexus/dotfiles/stow -t "$HOME" hypr
```

## Distro Support (Arch/Garuda vs Fedora)

`detect_distro()` in `scripts/lib/common.sh` inspects `/etc/os-release` (`ID` and `ID_LIKE`):

- **`arch`** (matches `arch`, `garuda`, `endeavouros`, `manjaro`, `cachyos`):
  - `install-packages.sh --category all` installs `common.txt`, `arch.txt`, `development.txt`, `desktop.txt`, and `fonts.txt` with `pacman -S --needed --noconfirm`, followed by `aur.txt` via `paru` (or `yay` fallback).
  - Supports `--category` values: `common`, `arch`, `development`, `desktop`, `fonts`, `aur`, `all`.
- **`fedora`** (matches `fedora`):
  - `install-packages.sh --category all` installs `fedora.txt` with `dnf install -y` (single combined manifest covering CLI, dev toolchains, terminals, and standard Wayland/audio/theming packages).
  - Supports `--category` values: `common`, `fedora`, `all`.
  - **Note**: Arch/AUR-only packages (`umbriel-git`, `noctalia-git`, `chaotic-*`, `garuda-*`, `snapper-support`, etc.) are not in `fedora.txt` and must be built or installed via COPR/source on Fedora if desired.

## Bootstrap Differences

- **Arch / Garuda**: Full parity with `desktop.txt`, `aur.txt`, and `system/etc/` reference configs (`pacman.conf`, `snapper`, `greetd`).
- **Fedora**: Use `./scripts/bootstrap.sh --distro` is not a `bootstrap.sh` flag (auto-detected by `install-packages.sh`), or run `./scripts/install-packages.sh --distro fedora --dry-run` first, then `./scripts/bootstrap.sh --skip-packages` if installing custom Wayland components manually.
