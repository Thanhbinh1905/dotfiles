# Workspace setup repository

Home Manager flake for one Linux workstation. The `features` set near the top
of `home.nix` selects its optional pieces; every feature defaults to `true` so
the default evaluates to the current workstation:

- **Appearance**, pinned in Nix: WhiteSur GTK/icon/cursor theme, GNOME `dconf`
  keys, dash-to-dock, fonts, desktop portals, VS Code settings, and the User
  Themes activation.
- **Vietnamese input**, pinned in Nix: Fcitx5 Lotus, its session variables, and
  the linked Fcitx5 configuration.
- **Config files**, symlinked out of the Nix store with `mkOutOfStoreSymlink`
  through `~/.dotfiles`. Editing a file under `home/` takes effect immediately;
  no rebuild.

## Optional pieces

`home.nix` is the single selection point. Each feature controls its packages and
linked files:

- `gui`: the Appearance piece above.
- `inputMethod`: Vietnamese input and `.xinputrc`.
- `ghostty`: the Ghostty package and config.
- `herdr`: the Herdr package and config.
- `shell`: zsh, the vendored dracula oh-my-zsh bundle, and `.zshrc`.
- `agentConfigs`: Claude, Codex, and pi policies and settings. Agent CLIs stay
  outside Nix.
- `developerTools`: cargo, curl, Docker, fd, fzf, GitHub and GitLab CLIs, Go,
  jq, kubectl, lazygit, Neovim, pyenv, Python and pip, ripgrep, Rust, tmux,
  unzip, Git config, and Neovim config.

`home/.config/nix/nix.conf` is always linked because it enables flakes and
`nix-command`.

Set a feature to `false`, run `./bootstrap.sh --check`, then apply with
`./bootstrap.sh`. For only the GUI layer, leave `gui = true` and turn the other
features off. For a headless setup, set `gui = false` and disable any desktop
features you do not need.

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
- Fcitx5 Lotus's user configuration and profile are linked from `home/` so input-method choices stay reviewable. Agent credentials, sessions and caches stay unmanaged because they contain secrets or runtime state.
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
