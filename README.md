# dotfiles

My Linux workstation, managed with Nix flakes and Home Manager.

## Apply

```sh
./bootstrap.sh
```

That links this repo to `~/.dotfiles` and switches to the generation described by
`home.nix`. Re-run it after changing a package list or a `dconf` key. To check a
change builds without touching the machine:

```sh
./bootstrap.sh --check
```

To reset just the desktop appearance - after GNOME Settings or another tool has
moved something - without building a generation:

```sh
./bootstrap.sh --appearance
```

## What is managed

`home.nix` is the whole configuration, with the `dconf` keys split into
`appearance.nix`. It does two different things.

**Pinned in Nix** - appearance and input method, so a fresh machine looks
identical: WhiteSur dark theme, icons and cursors, the GNOME User Themes
extension, dash-to-dock geometry, dark colour scheme, Fcitx5 Lotus for
Vietnamese input, and oh-my-zsh with the dracula prompt. Changing any of it means
editing `home.nix` or `appearance.nix` and re-running `./bootstrap.sh`.

`appearance.nix` holds every `dconf` key exactly once. `home.nix` feeds it to
`dconf.settings`, and `flake.nix` renders the same attrset into the standalone
`./bootstrap.sh --appearance` using Home Manager's own serializer, so the two
cannot drift.

**Symlinked out of the store** - every config file under `home/`, pointed at
through `~/.dotfiles` with `mkOutOfStoreSymlink`. The file in this repo *is* the
live config: edit `home/.zshrc` or `home/.config/nvim/` and the change is
already in effect. No rebuild.

Managed this way: zsh, Fcitx5's input-method profile, ghostty, neovim, herdr,
VS Code `settings.json`, and the agent settings for Claude and Pi. Pi's
OpenAI-compatible provider override is in `home/.pi/agent/models.json`; it
routes through the local cliproxyapi endpoint and disables the unsupported
explicit prompt-cache mode. The API key is read from the machine-local
`CLIPROXYAPI_API_KEY` environment variable and is never stored in this repo.
Set that variable in the shell or local environment file that launches Pi.

### Application-owned runtime state

Pi records the latest changelog it displayed, and Fcitx5 may append a blank
line when rewriting its profile. The tracked files remain the live symlink
targets, but `./bootstrap.sh` installs local Git clean filters that remove only
those generated changes before comparison. Deliberate configuration edits stay
visible in `git status`.

### Lotus host integration

Home Manager installs and starts Fcitx5 Lotus. Ubuntu still needs distro-native
GTK/Qt frontend modules and the system-level Lotus uinput server. Follow
[`docs/lotus-installation.md`](docs/lotus-installation.md) once per machine, then
log out and back in.

### The global agent policy

`home/AGENTS.md` is one policy file, linked into all three agents' global memory:

| Agent | Global memory path |
| --- | --- |
| Claude Code | `~/.claude/CLAUDE.md` |
| Codex | `~/.codex/AGENTS.md` |
| Pi | `~/.pi/agent/AGENTS.md` |

Edit `home/AGENTS.md` and all three see it on their next run. Keep it
project-agnostic - per-repository rules belong in that repository's own
`AGENTS.md`.

Note it is linked directly, not through a `CLAUDE.md` containing `@AGENTS.md`:
that import resolves relative to `~/.claude/`, so it would look for
`~/.claude/AGENTS.md`, which nothing creates.

## What is deliberately not managed

`~/.codex/config.toml`. Codex writes back into it: 29 per-project
`trust_level` entries, four `[mcp_servers]` blocks and hook trust hashes on this
machine. Linking it means every switch replaces that state with whatever the
repo happens to hold, and it would put a machine-specific trust list into git.
Codex owns that file. `~/.claude/settings.json` and `~/.pi/agent/settings.json`
are linked despite also being written back to, because what they write is
preferences rather than trust decisions. Git filters hide only the known
application-generated runtime fields; deliberate preference changes remain
reviewable.

`~/.config/opencode/AGENTS.md` is left alone too. Tools such as CodeGraph and
nodeterm inject marked blocks into it, and linking it would both write those
blocks into this repo and leak them into the policy Claude, Codex and Pi share.
opencode therefore does not get the global policy.


The agent CLIs themselves (`claude`, `codex`, `pi`) and the Node toolchain.
They self-update with `npm install -g`, which needs a writable prefix, and the
Nix store is read-only. They live under nvm, and `home/.zshrc` orders PATH so
nvm wins over the Nix profile. VS Code is installed by hand; only its
`settings.json` is linked.

Also unmanaged: application-owned runtime files not listed above, plus all
credentials, sessions and caches.

## Layout

| Path | What |
| --- | --- |
| `flake.nix` | Entry point. Holds the only copy of `username`. |
| `home.nix` | The entire Home Manager configuration. |
| `appearance.nix` | Every `dconf` key, once. Read by `home.nix` and by `--appearance`. |
| `bootstrap.sh` | Links `~/.dotfiles`, then switches. |
| `home/` | The real config files, symlinked into place. |
| `scripts/normalize-runtime-config.py` | Git clean-filter normalizer for application-owned runtime state. |
| `AGENTS.md` | Agent policy for working on this repo. |
