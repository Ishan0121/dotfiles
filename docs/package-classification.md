# Package Classification

All package and extension manifests live in `packages/`. Comments (`#`) and blank lines are ignored by `read_pkg_list()` in `scripts/lib/common.sh`.

## Manifest Summary

| Manifest | Target Installer | Scope & Grouping Rationale |
|---|---|---|
| `common.txt` | `pacman` / `dnf` | Cross-distro core CLI tools (`git`, `stow`, `zsh`, `neovim`, `starship`, `ripgrep`, `fd`, `fzf`, `bat`, `eza`, `zoxide`, `btop`, `htop`, `fastfetch`, `yazi`, `jq`, `rsync`, `curl`, `wget`, `shellcheck`, `tmux`, `cava`, `micro`, `ncdu`, `rclone`, archives, `xdg-*`, `tailscale`, `ufw`). |
| `arch.txt` | `pacman` | Arch & Garuda-specific system packages: `base-devel`, AUR helpers (`paru`, `yay`), `pacman-contrib`, `pacseek`, `rate-mirrors`, `downgrade`, `chaotic-*`, Btrfs/Snapper stack (`snapper-support`, `snapper-tools`, `btrfs-assistant`, `btrfs-progs`, `grub-btrfs`, `os-prober-btrfs`), `garuda-*`, `octopi`, `unifetch`. |
| `fedora.txt` | `dnf` | Fedora DNF equivalents for core CLI, compilers/toolchains (`gcc`, `gcc-c++`, `clang`, `cmake`, `ninja-build`, `python3`, `nodejs`, `golang`, `rustup`, `gdb`), terminals (`kitty`, `alacritty`, `foot`), and Wayland/audio/theming (`pipewire`, `wireplumber`, `mpv`, `mpd`, `swappy`, `fuzzel`, `qt5ct`, `qt6ct`, `kvantum`, `grim`, `slurp`, `wl-clipboard`). |
| `development.txt` | `pacman` | Compilers, runtimes, containers, and editors on Arch: `base-devel`, `nodejs`, `npm`, `python-pip`, `rustup`, `docker`, `docker-compose`, `podman`, `github-cli`, `visual-studio-code-bin`, `zed`, `geany`, `meld`, `android-sdk-platform-tools`, `opencode`, `postgresql`, `virt-manager-meta`. |
| `desktop.txt` | `pacman` | Wayland compositors (`umbriel-git`, `noctalia-git`, `noctalia-greeter`, `hyprland`, `hypridle`, `hyprlock`, `hyprpicker`, `niri`), portals/Wayland infra (`aquamarine`, `uwsm`, `xwayland-satellite`, `xdg-desktop-portal-*`), terminals/launchers, display/screenshot/clipboard tools, PipeWire/media players, and GTK/Qt/icon/cursor themes (`matugen`, `qt6ct`, `kvantum`, `nwg-look`, `adw-gtk-theme`, `bibata-cursor-theme`). |
| `fonts.txt` | `pacman` | System, CJK, emoji, and Nerd/coding fonts (`noto-fonts*`, `otf-font-awesome*`, `ttf-firacode-nerd`, `ttf-jetbrains-mono`, `ttf-nerd-fonts-symbols-mono`, etc.). |
| `aur.txt` | `paru` / `yay` | AUR-only packages (`antigravity-ide`, `appimagelauncher`, `eitype`, `epic-games-launcher-bin`, `staruml`, `swash`, `tela-circle-icon-theme-nord-git`, `voxtype-bin`, `win2xcur`). |
| `external.txt` | `scripts/setup-externals.sh` | Non-pacman git clones (`name\|target_relative_to_HOME\|git_url`): `oh-my-zsh`, `zsh-autosuggestions`, `zsh-completions`, `zsh-syntax-highlighting`, `kitty-themes`, and `lazyvim-starter`. Kept outside `dotfiles/` to avoid nested `.git` repos. |
| `vscode-extensions.txt` | `code --install-extension` | Exported VS Code extension IDs (149 entries) for manual or scripted restore. |
| `antigravity-extensions.txt` | `antigravity-ide --install-extension` | Exported Antigravity IDE extension IDs (15 entries). |

## Usage Examples

```bash
# Auto-detect distro and install all applicable manifests
./scripts/install-packages.sh

# Dry-run a single Arch category
./scripts/install-packages.sh --distro arch --category desktop --dry-run

# Dry-run Fedora manifest
./scripts/install-packages.sh --distro fedora --category fedora --dry-run

# Clone external git dependencies
./scripts/setup-externals.sh --dry-run
```
