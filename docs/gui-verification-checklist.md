# GUI & Wayland Verification Checklist

Use this manual checklist after deploying Stow packages on a live Wayland session.

## 1. Display Manager & Umbriel Compositor (Active)

- [ ] `greetd` / `noctalia-greeter` launches cleanly on VT 1 and logs into Umbriel.
- [ ] `~/.config/umbriel/config.toml` loads without parse errors; window rules and effects work.
- [ ] Monitor layout (`~/.config/umbriel/outputs.toml` or `outputs.toml.example`-derived config) matches physical displays, refresh rates, and scaling.
- [ ] Keybindings, workspace switching, and XWayland apps function as expected.

## 2. Noctalia Shell

- [ ] Noctalia bar, launcher, notification center, and control center start cleanly.
- [ ] Wallpaper switching / Wallhaven integration works (if `NOCTALIA_WALLHAVEN_API_KEY` is configured in `~/.config/noctalia/secrets.env` and rendered into `~/.config/noctalia/config.toml`).
- [ ] Hotspot plugin works (if `NOCTALIA_HOTSPOT_PASSWORD` is configured in `secrets.env`).
- [ ] Matugen / Noctalia dynamic color generation updates runtime theme files without modifying tracked files in `/mnt/nexus/dotfiles`.

## 3. Terminals & Shell

- [ ] **Kitty**: Opens with `~/.config/kitty/kitty.conf`, `current-theme.conf`, and `kitty-themes` intact; font autosize (`~/.local/bin/kitty-font-autosize.sh`) works.
- [ ] **Alacritty**: Opens with `~/.config/alacritty/alacritty.toml` without config warnings.
- [ ] **Foot**: Opens with `~/.config/foot/foot.ini` cleanly on Wayland.
- [ ] **Zsh + Starship**: Oh My Zsh, `zsh-autosuggestions`, `zsh-completions`, `zsh-syntax-highlighting`, and `starship` prompt render properly.

## 4. GTK, Qt & Kvantum Theming

- [ ] GTK3/GTK4 apps (e.g., Nautilus) pick up `~/.config/gtk-3.0/` and `~/.config/gtk-4.0/` themes and cursor settings.
- [ ] Qt5/Qt6 apps pick up `qt5ct`/`qt6ct` (`~/.config/qt5ct/`, `~/.config/qt6ct/`) and Kvantum (`~/.config/Kvantum/`) styling.
- [ ] `fuzzel` launcher and `swappy` screenshot editor launch and render with expected theme colors.

## 5. Editors & IDEs

- [ ] **Neovim**: `nvim` opens LazyVim cleanly with `lazy-lock.json` and zero plugin/init errors.
- [ ] **VS Code**: Launches with `~/.config/Code/User/settings.json`, keybindings, snippets, and profiles intact.
- [ ] **Antigravity IDE**: Launches with `~/.config/Antigravity IDE/User/settings.json` and snippets intact.
- [ ] **Zed**: Launches with `~/.config/zed/settings.json` intact.

## 6. Optional Sessions (`--profile all`)

- [ ] **Hyprland** (`hypr` package): Starts cleanly if selected; `hypridle`/`hyprlock` behave properly.
- [ ] **Niri** (`niri` package): Starts cleanly if selected; scrollable tiling and keybinds work.
