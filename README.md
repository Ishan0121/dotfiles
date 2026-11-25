# Garuda Linux Modular Dotfiles

Modular, GNU Stow-managed user configuration repository stored on the persistent `/mnt/nexus` Btrfs partition (`/mnt/nexus/dotfiles`).

## Quick Start

```bash
# 1. Inspect dependencies
./scripts/check-deps.sh

# 2. Preview the full bootstrap without modifying files
./scripts/bootstrap.sh --dry-run

# 3. Run full bootstrap (active profile: 20 packages, excludes hypr/niri)
./scripts/bootstrap.sh

# 4. Or deploy only Stow symlinks after reviewing status
./scripts/stow-manage.sh status --profile active
./scripts/stow-manage.sh deploy --profile active
```

## Architecture Overview

- **`stow/`** — 22 independent GNU Stow packages deployed to `$HOME` using `--no-folding` for shared and runtime-mutated directories.
- **`packages/`** — Categorized package and extension manifests (`common`, `arch`, `fedora`, `development`, `desktop`, `fonts`, `aur`, `external`, `vscode-extensions`, `antigravity-extensions`).
- **`scripts/`** — Idempotent, `--dry-run`-capable automation for dependency checks, backups, package installation, external git clones, Stow deployment, and secret scanning.
- **`system/`** — Non-Stow `/etc` reference copies and manual root-required restoration notes (never stowed or auto-written).
- **`docs/`** — Detailed guides for architecture, packages, profiles/distros, security, troubleshooting, and GUI verification.
- **`tests/`** — Requirement-driven E2E test suite.
- **Outside Git on `/mnt/nexus`**:
  - `/mnt/nexus/dotfiles-backups/` — Pre-Stow `$HOME` backups managed by `scripts/backup-restore.sh`.
  - `/mnt/nexus/dotfiles-archive/` — `0700`-isolated historical config archive (read-only reference, never tracked in Git).

## Stow Packages (`stow/`)

### Active Profile (`--profile active`, 20 packages)

| Package | Target Path(s) | Notes |
|---|---|---|
| `zsh` | `~/.zshrc` | Oh My Zsh + 3 plugins managed via `setup-externals.sh` |
| `bash` | `~/.bashrc`, `~/.bash_profile`, `~/.bash_logout`, `~/.profile` | Standard login & interactive Bash setup |
| `git` | `~/.gitconfig` | Includes `~/.gitconfig.local` for machine-local identity |
| `starship` | `~/.config/starship.toml` | Cross-shell prompt (`--no-folding`) |
| `kitty` | `~/.config/kitty/` | Config, theme symlink, userprefs, theme picker (`kitty-themes` via `setup-externals.sh`) |
| `alacritty` | `~/.config/alacritty/alacritty.toml` | GPU-accelerated terminal config |
| `foot` | `~/.config/foot/foot.ini` | Lightweight Wayland terminal config |
| `cli` | `~/.dircolors`, `~/.gdbinit`, `~/.config/{htop,btop,fastfetch,yazi,cava,micro,pacseek,unifetch}` | CLI utilities and system monitors |
| `media` | `~/.config/{mpd,mpv,swappy}` | Audio, video, and screenshot annotation |
| `bin` | `~/.local/bin/` | Helper scripts (`kitty-font-autosize.sh`, `mon.sh`, `nmtui-colors`, `battery_warn.sh`, `keyhint.sh`, `bear/implement_gum.sh`) |
| `xdg` | `~/.config/{user-dirs.*,mimeapps.list,environment.d,autostart,systemd/user}`, `~/.local/share/{fonts,applications}` | XDG user dirs, MIME defaults, user units, desktop entries |
| `umbriel` | `~/.config/umbriel/` | **Active Wayland compositor** (`config.toml`, `effects/`, `outputs.toml.example`) |
| `noctalia` | `~/.config/noctalia/` | **Active Wayland shell** (`secrets.env.example`; `config.toml` rendered locally from template) |
| `gtk` | `~/.gtkrc-2.0`, `~/.Xresources`, `~/.config/gtk-{3.0,4.0}/` | GTK2/3/4 theming (`--no-folding` for Noctalia runtime CSS) |
| `qt` | `~/.config/qt5ct/`, `~/.config/qt6ct/`, `~/.config/Kvantum/` | Qt5/Qt6 & Kvantum theming |
| `desktop-extras` | `~/.config/{fuzzel,strata,luciole,voxtype}` | Launcher, overlay, and voice/desktop utilities |
| `nvim` | `~/.config/nvim/` | LazyVim user config + `lazy-lock.json` (starter cloned via `setup-externals.sh`) |
| `vscode` | `~/.config/Code/User/` | `settings.json`, `keybindings.json`, `snippets/`, `profiles/` (caches/DBs excluded) |
| `antigravity` | `~/.config/Antigravity IDE/User/` | `settings.json`, `snippets/` (caches/DBs/creds excluded) |
| `zed` | `~/.config/zed/settings.json` | Zed editor settings (`themes/noctalia.json` gitignored) |

### Optional Profiles (`--profile all`, +2 packages = 22 total)

| Package | Target Path(s) | Notes |
|---|---|---|
| `hypr` | `~/.config/hypr/` | Optional Hyprland session config |
| `niri` | `~/.config/niri/` | Optional Niri scrollable-tiling compositor config |

## Bootstrap & Script Usage

All scripts under `scripts/` support `--help` and non-destructive `--dry-run`:

```bash
# Full bootstrap with dry-run
./scripts/bootstrap.sh --dry-run

# Bootstrap skipping system packages or external clones
./scripts/bootstrap.sh --skip-packages --skip-externals

# Stow management
./scripts/stow-manage.sh status --profile active
./scripts/stow-manage.sh deploy --profile active
./scripts/stow-manage.sh restow --profile all
./scripts/stow-manage.sh undeploy --profile active

# Install packages (Arch/Garuda or Fedora)
./scripts/install-packages.sh --dry-run
./scripts/install-packages.sh --distro arch --category common

# Clone external git dependencies (OMZ, zsh plugins, kitty-themes, LazyVim)
./scripts/setup-externals.sh --dry-run

# Run secret, nested-.git, database, and hardcoded-path audit
./scripts/check-secrets.sh
```

## Noctalia Secrets Handling

`stow/noctalia/.config/noctalia/config.toml` is a sanitized template using placeholders (`REPLACE_WITH_HOTSPOT_PASSWORD` and `REPLACE_WITH_WALLHAVEN_API_KEY`).

1. `stow-manage.sh` ignores `config.toml` when running `stow` (`--ignore='config\.toml'`) so your live config is never overwritten by a symlink.
2. Copy `stow/noctalia/.config/noctalia/secrets.env.example` to `~/.config/noctalia/secrets.env` (gitignored) and fill in your real values.
3. On `deploy` or `restow`, `render_noctalia_config` preserves an existing `~/.config/noctalia/config.toml` unless `--force-noctalia-render` is passed; when rendering, it substitutes `NOCTALIA_HOTSPOT_PASSWORD` and `NOCTALIA_WALLHAVEN_API_KEY` and writes `~/.config/noctalia/config.toml` with mode `0600`.

## Backup & Rollback

```bash
# Create a timestamped backup of colliding $HOME files before stowing
./scripts/backup-restore.sh backup

# List available backups under /mnt/nexus/dotfiles-backups
./scripts/backup-restore.sh list

# Rollback: undeploy symlinks, then restore a backup directory
./scripts/stow-manage.sh undeploy --profile active
./scripts/backup-restore.sh restore /mnt/nexus/dotfiles-backups/<backup-dir>
```

## Documentation

- [Architecture](file:///mnt/nexus/dotfiles/docs/architecture.md) — `/mnt/nexus` Btrfs layout, Stow `--no-folding`, and repo layers
- [Package Classification](file:///mnt/nexus/dotfiles/docs/package-classification.md) — Guide to every `packages/*.txt` manifest
- [Profiles & Distros](file:///mnt/nexus/dotfiles/docs/profiles-and-distros.md) — Active vs optional compositor profiles and Arch vs Fedora differences
- [Security](file:///mnt/nexus/dotfiles/docs/security.md) — `.gitignore` layers, Noctalia secrets contract, `check-secrets.sh`, and pre-push checklist
- [Troubleshooting](file:///mnt/nexus/dotfiles/docs/troubleshooting.md) — Stow conflicts, symlinks, Noctalia runtime files, rollback, and `/etc` recovery
- [GUI Verification Checklist](file:///mnt/nexus/dotfiles/docs/gui-verification-checklist.md) — Manual Wayland, compositor, terminal, theming, and IDE checks
- [System `/etc` Reference](file:///mnt/nexus/dotfiles/system/README.md) — Non-Stow `/etc` reference files and manual `sudo` restore steps
