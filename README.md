# Garuda Linux Modular Dotfiles

Modular, GNU Stow-managed user configuration repository stored on the persistent `/mnt/nexus` Btrfs partition (`/mnt/nexus/dotfiles`).

> **Status:** Initialized (Milestone 1). Package migration, bootstrap scripts, validation, and full documentation are in progress.

## Directory Layout

- `stow/` — Independent GNU Stow user packages (deployed to `$HOME`, using `--no-folding` for runtime-mutated app directories)
- `packages/` — Categorized package & extension manifests (`common`, `arch`, `fedora`, `development`, `desktop`, `fonts`, `aur`, `external`, IDE extensions)
- `scripts/` — Dry-run-capable bootstrap, Stow management, backup/restore, dependency, and secret-audit scripts
- `system/` — Separate non-Stow `/etc` reference copies and root-required restoration notes
- `docs/` — Architecture, profile/distro guides, security, troubleshooting, and GUI/Wayland verification checklist
- `tests/` — Requirement-driven E2E test suite

## Repository Policy

- Local-only repository (`main` branch); no remote configured until explicitly approved for a private GitHub repository.
- Secrets, private keys, browser profiles/cookies, histories, caches, nested `.git` clones, and Noctalia runtime-generated theme files are excluded via `.gitignore` and archived/stored outside Git.
