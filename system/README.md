# System `/etc` Reference Copies (Non-Stow)

> **IMPORTANT:** Files under `system/etc/` are **reference copies only**. They are **never** deployed with GNU Stow and are **never** automatically written by bootstrap scripts. Modifying `/etc` requires `sudo` and explicit manual review on the target host.

## Included Reference Files

| Path in Repo | System Path | Purpose |
|---|---|---|
| `system/etc/fstab` | `/etc/fstab` | Btrfs subvolume layout (`@`, `@home`, `@root`, `@srv`, `@cache`, `@log`, `@tmp`) and `/mnt/nexus` persistent partition mount (`UUID=5ce463f7-fb65-4d77-b0ec-a1b3e4ccec6e`, `nofail`) |
| `system/etc/environment` | `/etc/environment` | System-wide PAM environment variables (`QT_QPA_PLATFORMTHEME=qt5ct`, `GTK_THEME=Sweet-Dark`) |
| `system/etc/pacman.conf` | `/etc/pacman.conf` | Pacman configuration (repositories, parallel downloads, hooks/options) |
| `system/etc/default/grub` | `/etc/default/grub` | GRUB bootloader kernel parameters and theme/timeout settings |
| `system/etc/greetd/config.toml` | `/etc/greetd/config.toml` | `greetd` display manager config (`/usr/bin/noctalia-greeter-session` as `greeter` on VT 1) |
| `system/etc/snapper/config-templates/garuda` | `/etc/snapper/config-templates/garuda` | Garuda Btrfs snapshot template |
| `system/etc/snapper/configs/root` | `/etc/snapper/configs/root` | Active Snapper configuration for `/` |
| `system/etc/nix/nix.conf` | `/etc/nix/nix.conf` | Determinate Nix base configuration |
| `system/etc/nix/nix.custom.conf` | `/etc/nix/nix.custom.conf` | Determinate Nix custom overrides |

> Note: Files requiring root-only read permissions or containing service endpoints (such as `/etc/nix/sentry-endpoint`) are intentionally omitted.

## Manual Restoration Guidelines

Always diff against the live system before copying, and adapt UUIDs/hardware-specific values on a new machine:

```bash
# Example: compare a reference file with the live system
diff -u /etc/pacman.conf system/etc/pacman.conf

# Example: restore pacman.conf or environment (requires sudo)
sudo cp system/etc/pacman.conf /etc/pacman.conf
sudo cp system/etc/environment /etc/environment

# Example: restore greetd config (requires sudo)
sudo cp system/etc/greetd/config.toml /etc/greetd/config.toml

# Example: after reviewing and updating /etc/default/grub, regenerate GRUB config
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

Never blindly overwrite `/etc/fstab` on a different machine—update the partition `UUID=` values from `blkid` first.
