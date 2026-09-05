# Workspace setup repository

Home Manager flake for one Linux workstation. Two things are managed, nothing else:

- **Appearance and input method**, pinned in Nix: WhiteSur GTK/icon/cursor theme, GNOME `dconf` keys, dash-to-dock, Fcitx5 Lotus, oh-my-zsh with the vendored dracula prompt. The `dconf` keys live in `appearance.nix`; everything else in `home.nix`.
- **Config files**, symlinked out of the Nix store with `mkOutOfStoreSymlink` through `~/.dotfiles`. Editing a file under `home/` takes effect immediately; no rebuild.

## Rules

- Agent CLIs (claude, codex, pi) and the Node toolchain are not installed here. They self-update with `npm install -g`, which needs a writable prefix; the Nix store is not one. Nix must never put `node`/`npm` on PATH ahead of nvm - see the ordering comment in `home/.zshrc`.
- No flake inputs that are git repositories. Only `nixpkgs` and `home-manager`.
- `flake.nix` holds the only copy of `username`. Everything else derives from it.
- `appearance.nix` is the only place a `dconf` key is written. Both consumers - `dconf.settings` in `home.nix` and `packages.appearance` in `flake.nix` - import that one attrset and render it with Home Manager's own serializer. A second consumer is fine; restating a key by hand is not. Verify with:
  `diff <(rendered keyfile from packages.appearance) <(the generation's hm-dconf.ini)` - they must be byte-identical.
- One global agent policy: `home/AGENTS.md`, linked to `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md` and `~/.pi/agent/AGENTS.md`. Keep it project-agnostic. Do not use Claude's `@AGENTS.md` import for it - inside `~/.claude/CLAUDE.md` that resolves to `~/.claude/AGENTS.md`, which nothing creates.
- Do not link a file the app writes trust decisions or credentials into. `~/.codex/config.toml` is the case in point: codex stores project `trust_level` entries, `[mcp_servers]` and hook hashes there, so linking it both wipes them on switch and would commit a machine-specific trust list. It stays unmanaged.
- Linking a file the app merely writes preferences back into is fine. Absorb that write by committing the file exactly as the app serializes it - Fcitx5's profile ends with a blank line - and only where the value itself keeps changing by a Git clean filter that drops that one field. `scripts/normalize-pi-settings.py` is the only such filter; deliberate preference edits must stay reviewable.
- This repository is public. A managed file that needs a secret references it, never contains it: `home/.pi/agent/models.json` resolves the cliproxyapi key at runtime with pi's `!command` syntax from `~/.pi/agent/cliproxyapi.local`, which `bootstrap.sh` seeds. Verify any such mechanism by running the application, not by reasoning about it.
- Fcitx5 Lotus's writable config, agent credentials, sessions and caches stay unmanaged. Only the input-method profile is linked from `home/`.
- Activation must not hard-fail on an absent desktop session. Report and continue.
- Never commit credentials, tokens, account databases, runtime state, or package caches.
- Never manually modify generated lockfiles or generated changelogs. Update them only through their owning tool.
- Never use em dash punctuation. Use a plain hyphen instead.

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.

## Commands

- `./bootstrap.sh --check` - evaluate and dry-build, change nothing.
- `./bootstrap.sh` - link `~/.dotfiles` and switch. Conflicting files become `<file>.bak`.
- `./bootstrap.sh --appearance` - apply only the `dconf` keys, no generation.
