# Garuda Linux Modular Dotfiles

Modular, [GNU Stow](https://www.gnu.org/software/stow/)-managed Linux configuration repository stored on the persistent `/mnt/nexus` Btrfs partition (`/mnt/nexus/dotfiles`). Designed to keep active desktop, shell, and editor settings portable across **Arch / Garuda** and **Fedora** installs—completely separated from OS caches, temporary files, and private credentials.

## Why It's Built This Way

Normally, Linux settings live inside `$HOME` (`~`), mixed together with gigabytes of app caches, runtime state, and secrets. Reinstalling or switching distros wipes or tangles everything. This setup solves that in four ways:

1. **Persistent Storage (`/mnt/nexus`)** — Configs live on a dedicated Btrfs partition mounted at `/mnt/nexus`, keeping them untouched by OS reinstalls or root-subvolume Snapper rollbacks.
2. **Clean, Modular Packages (`stow/`)** — Active configs (Zsh, Umbriel, Noctalia, Neovim, VS Code, etc.) are separated from optional compositors (Hyprland, Niri) and stripped of caches, databases, and secrets.
3. **Symlinked Back to `$HOME` via GNU Stow** — Apps still read `~/.config/...` as usual, following symlinks directly into `/mnt/nexus/dotfiles`. Any tweak you make is immediately inside your Git repo.
4. **Idempotent Bootstrap Scripts (`scripts/`)** — On a fresh Arch, Garuda, or Fedora install, one command checks dependencies, backs up defaults, installs packages, clones external plugins (Oh My Zsh, LazyVim, Kitty themes), and deploys all symlinks.

---

## The Three Folders on `/mnt/nexus`

Only `/mnt/nexus/dotfiles` is tracked in Git. The other two directories stay strictly local on `/mnt/nexus`:

| Path | In Git? | Purpose |
| --- | --- | --- |
| `/mnt/nexus/dotfiles` | Yes (Private repo) | Clean, active, portable configs (`stow/`), package lists (`packages/`), automation (`scripts/`), `/etc` reference notes (`system/`), and docs (`docs/`). |
| `/mnt/nexus/dotfiles-archive` | No (local, `0700`) | Read-only "attic" holding retired configs and old `.bak` files for reference without cluttering Git. |
| `/mnt/nexus/dotfiles-backups` | No (local) | Timestamped pre-Stow `$HOME` snapshots created by `scripts/backup-restore.sh` for full rollback. |

---

## Prerequisites

- **`git`** and **`stow`** (required)
  - **Arch / Garuda:** `sudo pacman -S git stow`
  - **Fedora:** `sudo dnf install git stow`
- **Optional:** An AUR helper (`paru` or `yay`) on Arch/Garuda if installing AUR packages via `install-packages.sh`.

---

## Fresh Machine Setup (Restore Guide)

### 1. Clone the Repository

Clone your private repository onto your data drive (recommended: `/mnt/nexus/dotfiles`) or `~/dotfiles`:

```bash
git clone <your-private-github-repo-url> /mnt/nexus/dotfiles
cd /mnt/nexus/dotfiles
```

### 2. Preview First (Recommended, Non-Destructive)

```bash
# Check required and optional tools
./scripts/check-deps.sh

# Simulate the full bootstrap without modifying any files
./scripts/bootstrap.sh --dry-run
```

### 3. Run the Bootstrap

```bash
# Full bootstrap (active profile: 20 packages, excludes hypr/niri)
./scripts/bootstrap.sh

# Or include optional Hyprland and Niri configs (22 packages total)
./scripts/bootstrap.sh --profile all
```

`bootstrap.sh` runs these 6 steps automatically in order:

| Step | Script | What it does | How to skip |
| --- | --- | --- | --- |
| 1 | `check-deps.sh` | Checks that `git`, `stow`, and helper tools are installed | — |
| 2 | `backup-restore.sh` | Saves a copy of any existing `$HOME` files that would conflict | `--no-backup` |
| 3 | `install-packages.sh` | Installs apps & fonts from `packages/*.txt` (Arch/Garuda or Fedora) | `--skip-packages` |
| 4 | `setup-externals.sh` | Clones Oh My Zsh, Zsh plugins, `kitty-themes`, and LazyVim starter | `--skip-externals` |
| 5 | `stow-manage.sh` | Creates `$HOME` symlinks into `/mnt/nexus/dotfiles` (`--no-folding`) | — |
| 6 | `check-secrets.sh` | Audits `stow/` and `system/` for accidental secrets or nested `.git` | — |

### 4. Restore Private Secrets & Local Identity

Secrets are never committed to Git:

- **Noctalia secrets:** Copy `stow/noctalia/.config/noctalia/secrets.env.example` to `~/.config/noctalia/secrets.env`, fill in `NOCTALIA_HOTSPOT_PASSWORD` and `NOCTALIA_WALLHAVEN_API_KEY`, then run:
  ```bash
  ./scripts/stow-manage.sh deploy --profile active
  ```
- **Git identity:** Create `~/.gitconfig.local` with your machine-local `[user]` name/email (included by `stow/git/.gitconfig`).
- **Keys & remotes:** Restore SSH keys, GPG keys, or `rclone` configs separately from a secure offline backup.

### 5. Optional Extras

- **Editor extensions:** Reinstall VS Code or Antigravity extensions from `packages/vscode-extensions.txt` and `packages/antigravity-extensions.txt`.
- **System `/etc` tweaks:** Review [system/README.md](./system/README.md) to manually reapply root-owned system configs (`fstab`, `greetd`, `pacman.conf`, `snapper`, etc.) with `sudo` if desired.

---

## Repository Structure

```text
/mnt/nexus/dotfiles/
├── stow/        # 22 modular GNU Stow packages (20 active + 2 optional)
├── packages/    # Categorized distro, AUR, font, external, and IDE extension lists
├── scripts/     # Idempotent, --dry-run-capable setup, stow, backup, and audit scripts
├── system/      # Non-Stow /etc reference copies and manual sudo restore notes
├── docs/        # Architecture, package, profile, security, troubleshooting, and GUI docs
└── tests/       # 4-tier E2E test suite (run_all.sh)
```

---

## Stow Packages (`stow/`)

### Active Profile (`--profile active`, 20 packages)

| Package | Target Path(s) | Notes |
| --- | --- | --- |
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

### Optional Profile (`--profile all`, +2 packages = 22 total)

| Package | Target Path(s) | Notes |
| --- | --- | --- |
| `hypr` | `~/.config/hypr/` | Optional Hyprland session config |
| `niri` | `~/.config/niri/` | Optional Niri scrollable-tiling compositor config |

---

## Which Script Should I Run? (`scripts/`)

Every script supports `--help`, and any script that changes files supports `--dry-run` so you can preview safely first.

| When you want to… | Script | Example command |
| --- | --- | --- |
| **Set up a brand-new PC** (all 6 steps) | `bootstrap.sh` | `./scripts/bootstrap.sh` *(or `--dry-run` first)* |
| **Link or unlink configs** without installing apps | `stow-manage.sh` | `./scripts/stow-manage.sh deploy --profile active` |
| **Check which symlinks** would change | `stow-manage.sh` | `./scripts/stow-manage.sh status --profile active` |
| **Install apps & fonts** from `packages/*.txt` | `install-packages.sh` | `./scripts/install-packages.sh --distro arch --category common` |
| **Download Oh My Zsh, LazyVim, Kitty themes** | `setup-externals.sh` | `./scripts/setup-externals.sh` |
| **Back up or undo** `$HOME` files | `backup-restore.sh` | `./scripts/backup-restore.sh backup` / `list` / `restore <dir>` |
| **Check required tools** are installed | `check-deps.sh` | `./scripts/check-deps.sh` |
| **Scan for leaked passwords/keys** before `git push` | `check-secrets.sh` | `./scripts/check-secrets.sh` |

<details>
<summary>Common script flags &amp; options</summary>

- `bootstrap.sh`: `--profile <active|all>`, `--skip-packages`, `--skip-externals`, `--no-backup`, `--dry-run`
- `stow-manage.sh`: actions `status | deploy | restow | undeploy`, `--profile <active|all>`, `--force-noctalia-render`, `--dry-run`
- `install-packages.sh`: `--distro <auto|arch|fedora>`, `--category <common|arch|fedora|development|desktop|fonts|aur|all>`, `--dry-run`
- `backup-restore.sh`: actions `backup | list | restore <dir>`, `--target <dir>`, `--backup-dir <dir>`, `--dry-run`

</details>

---

## Noctalia Secrets Handling

`stow/noctalia/.config/noctalia/config.toml` is a sanitized template using placeholders (`REPLACE_WITH_HOTSPOT_PASSWORD` and `REPLACE_WITH_WALLHAVEN_API_KEY`).

1. `stow-manage.sh` passes `--ignore='config\.toml'` to `stow` so your live config is never overwritten by a symlink.
2. Copy `stow/noctalia/.config/noctalia/secrets.env.example` to `~/.config/noctalia/secrets.env` (gitignored) and set `NOCTALIA_HOTSPOT_PASSWORD` and `NOCTALIA_WALLHAVEN_API_KEY`.
3. On `deploy` or `restow`, `render_noctalia_config` preserves an existing `~/.config/noctalia/config.toml` unless `--force-noctalia-render` is passed; when rendering, it substitutes the environment values and writes `~/.config/noctalia/config.toml` with mode `0600`.

---

## Backup & Rollback

```bash
# Create a timestamped backup of colliding $HOME files before stowing
./scripts/backup-restore.sh backup

# List available backups under /mnt/nexus/dotfiles-backups
./scripts/backup-restore.sh list

# Rollback: remove symlinks, then restore a saved snapshot
./scripts/stow-manage.sh undeploy --profile active
./scripts/backup-restore.sh restore /mnt/nexus/dotfiles-backups/<backup-dir>
```

---

## Testing

Run the 4-tier E2E test suite (static/secret checks, backup/restore, Stow lifecycle, and bootstrap `--dry-run`):

```bash
./tests/run_all.sh
```

---

## Documentation

- [Architecture](./docs/architecture.md) — `/mnt/nexus` Btrfs layout, Stow `--no-folding`, and repo layers
- [Package Classification](./docs/package-classification.md) — Guide to every `packages/*.txt` manifest
- [Profiles & Distros](./docs/profiles-and-distros.md) — Active vs optional compositor profiles and Arch vs Fedora differences
- [Security](./docs/security.md) — `.gitignore` layers, Noctalia secrets contract, `check-secrets.sh`, and pre-push checklist
- [Troubleshooting](./docs/troubleshooting.md) — Stow conflicts, symlinks, Noctalia runtime files, rollback, and `/etc` recovery
- [GUI Verification Checklist](./docs/gui-verification-checklist.md) — Manual Wayland, compositor, terminal, theming, and IDE checks
- [System `/etc` Reference](./system/README.md) — Non-Stow `/etc` reference files and manual `sudo` restore steps
