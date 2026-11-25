# Troubleshooting & Recovery

## 1. Stow Conflicts (`existing target is neither a link nor a directory`)

If a real file already exists in `$HOME` where Stow wants to create a symlink:

1. Back up colliding files first:
   ```bash
   ./scripts/backup-restore.sh backup
   ```
2. Inspect the conflict with a dry-run status check:
   ```bash
   ./scripts/stow-manage.sh status --profile active
   ```
3. Move or remove the conflicting file in `$HOME` (after confirming it is backed up under `/mnt/nexus/dotfiles-backups/`), then re-run:
   ```bash
   ./scripts/stow-manage.sh deploy --profile active
   ```

## 2. Broken or Absolute Symlink Issues

Check for broken symlinks in `$HOME` config directories:

```bash
find "$HOME/.config" "$HOME/.local/bin" -xtype l 2>/dev/null
```

If symlinks point to an old location or another package, undeploy and restow cleanly:

```bash
./scripts/stow-manage.sh undeploy --profile active
./scripts/stow-manage.sh deploy --profile active
```

## 3. `--no-folding` Behavior

`stow-manage.sh` always passes `--no-folding`. If you manually run `stow` without `--no-folding`, Stow may replace a directory in `$HOME` with a single directory symlink, causing runtime-generated files (themes, caches, databases) to appear inside `/mnt/nexus/dotfiles/stow/`.

To fix a folded directory:
1. Undeploy the affected package: `stow -D -d /mnt/nexus/dotfiles/stow -t "$HOME" <pkg>`
2. Re-deploy with `--no-folding`: `stow --no-folding -d /mnt/nexus/dotfiles/stow -t "$HOME" <pkg>`

## 4. Noctalia Runtime-Generated Files & `config.toml`

- **Runtime theme files** (`noctalia.toml`, `noctalia.kdl`, `noctalia.lua`, `dank-colors.css`, `themes/noctalia.json`, `outputs.toml`, etc.) are generated at runtime in `$HOME` and ignored by `.gitignore`. Do not force-add them.
- **`~/.config/noctalia/config.toml`** is intentionally excluded from Stow (`--ignore='config\.toml'`) and managed as a `0600` file.
  - Existing `config.toml` is preserved on `deploy`/`restow`.
  - To regenerate it from the repo template and `~/.config/noctalia/secrets.env`:
    ```bash
    ./scripts/stow-manage.sh deploy --profile active --force-noctalia-render
    ```

## 5. Rollback via `scripts/backup-restore.sh`

To revert `$HOME` to a pre-Stow backup:

```bash
# 1. List available backups
./scripts/backup-restore.sh list

# 2. Remove Stow symlinks
./scripts/stow-manage.sh undeploy --profile active

# 3. Preview restore, then execute
./scripts/backup-restore.sh restore /mnt/nexus/dotfiles-backups/<backup-dir> --dry-run
./scripts/backup-restore.sh restore /mnt/nexus/dotfiles-backups/<backup-dir>
```

## 6. `/etc` Manual Recovery

Files under `system/etc/` are reference copies only and are never touched by Stow or `bootstrap.sh`. To recover a system file:

1. Diff the live file against the reference copy:
   ```bash
   diff -u /etc/pacman.conf system/etc/pacman.conf
   ```
2. Copy manually with `sudo` after verifying host-specific values (especially `UUID=` entries in `/etc/fstab`):
   ```bash
   sudo cp system/etc/environment /etc/environment
   ```
3. For GRUB changes, regenerate `/boot/grub/grub.cfg`:
   ```bash
   sudo grub-mkconfig -o /boot/grub/grub.cfg
   ```
