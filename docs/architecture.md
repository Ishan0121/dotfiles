# Architecture

## Persistent Btrfs Storage (`/mnt/nexus`)

The dotfiles ecosystem lives on a dedicated Btrfs partition mounted at `/mnt/nexus` (`LABEL=NEXUS`, `defaults,noatime,compress=zstd,nofail 0 0` in `/etc/fstab`), keeping user configuration and backups independent of the root subvolume (`@`) and Snapper rollbacks:

| Path | Tracked in Git | Purpose |
|---|---|---|
| `/mnt/nexus/dotfiles` | Yes (`main`) | Modular GNU Stow repository (`lucifer:lucifer`) |
| `/mnt/nexus/dotfiles-backups` | No | Timestamped pre-Stow `$HOME` backups created by `scripts/backup-restore.sh` |
| `/mnt/nexus/dotfiles-archive` | No (`0700`) | Historical config snapshot (`ARCHIVE_MANIFEST.md`, `ARCHIVE_SHA256SUMS.txt`, raw old configs) |

## Repository Layers

```text
/mnt/nexus/dotfiles/
├── stow/        # 22 modular GNU Stow packages mirroring $HOME
├── packages/    # Categorized pacman, AUR, DNF, external git, and IDE extension manifests
├── scripts/     # Idempotent, --dry-run-capable setup, deploy, backup, and audit scripts
├── system/      # Non-Stow /etc reference copies and manual sudo restore instructions
├── docs/        # Architecture, package, profile/distro, security, troubleshooting, GUI docs
└── tests/       # Requirement-driven E2E test suite
```

## GNU Stow Layer (`stow/` & `--no-folding`)

Each subdirectory under `stow/<pkg>/` mirrors `$HOME` (for example, `stow/kitty/.config/kitty/kitty.conf` links to `~/.config/kitty/kitty.conf`).

`scripts/stow-manage.sh` invokes Stow with:

```bash
stow --no-folding -d "$STOW_DIR" -t "$TARGET_DIR" <pkg>
```

**Why `--no-folding` is required:**
- Without `--no-folding`, Stow folds entire directories into a single directory symlink (e.g., `~/.config/kitty -> /mnt/nexus/dotfiles/stow/kitty/.config/kitty`).
- Many applications write runtime files, caches, databases, or generated themes into those same directories (e.g., Noctalia writing `noctalia.toml`, `noctalia.kdl`, `dank-colors.css`, or VS Code/Antigravity writing `globalStorage/` and `.vscdb` state).
- With `--no-folding`, Stow creates real directories in `$HOME` and symlinks only the individual tracked files, preventing runtime-generated or machine-specific files from polluting the Git working tree.

### Special Handling for `noctalia`

`stow-manage.sh` passes `--ignore='config\.toml'` when stowing `noctalia`, then calls `render_noctalia_config` to copy/render `~/.config/noctalia/config.toml` as a regular `0600` file rather than a symlink. This keeps secrets out of Git while preserving Noctalia's ability to mutate its own config locally.

## Non-Stow Layers

- **`packages/`**: Plain-text manifests parsed by `read_pkg_list()` in `scripts/lib/common.sh` (strips `#` comments and blank lines) and `setup-externals.sh`.
- **`scripts/`**:
  - `lib/common.sh` — Shared logging, `DRY_RUN` wrapper (`run_cmd`), `detect_distro()`, and `read_pkg_list()`.
  - `bootstrap.sh` — 6-step orchestrator (`check-deps` -> `backup-restore` -> `install-packages` -> `setup-externals` -> `stow-manage` -> `check-secrets`).
  - `stow-manage.sh` — `deploy`, `undeploy`, `restow`, `status` across `active` (20 packages) or `all` (22 packages).
  - `backup-restore.sh` — `backup`, `restore <dir>`, `list` for colliding `$HOME` files.
  - `install-packages.sh` — Installs `packages/*.txt` via `pacman`, `paru`/`yay`, or `dnf`.
  - `setup-externals.sh` — Clones `packages/external.txt` repositories (`--depth 1`) into `$HOME` without nesting `.git` inside `dotfiles/`.
  - `check-deps.sh` — Verifies required (`stow`, `git`, `rsync`, `bash`) and optional tools.
  - `check-secrets.sh` — Scans `stow/` and `system/` for nested `.git`, databases, private keys, tokens, non-placeholder credentials, and hardcoded paths.
- **`system/`**: Reference copies of `/etc/fstab`, `/etc/environment`, `/etc/pacman.conf`, `/etc/default/grub`, `/etc/greetd/config.toml`, `/etc/snapper/`, and `/etc/nix/`. Never stowed; see [system/README.md](file:///mnt/nexus/dotfiles/system/README.md).
- **`tests/`**: Isolated E2E test harness and checks validating bootstrap, Stow, rollback, and security invariants.
