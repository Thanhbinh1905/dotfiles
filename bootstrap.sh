#!/usr/bin/env bash
# Applies this repo's Home Manager config. Safe to re-run for every change.
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: bootstrap.sh [--check|--appearance]

  (no args)     Link ~/.dotfiles and switch to this repo's Home Manager generation.
  --check       Evaluate and dry-build the activation package, changing nothing.
  --appearance  Apply only the GNOME appearance and input-source keys.

Existing files that Home Manager wants to own are renamed to <file>.bak
instead of blocking the run.
USAGE
}

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
dotfiles_link="${HOME:?HOME is not set}/.dotfiles"

case "${1:-}" in
  "") ;;
  --check) check_only=1 ;;
  --appearance) appearance_only=1 ;;
  --help | -h) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

command -v nix >/dev/null || { echo "nix is required" >&2; exit 1; }
export NIX_CONFIG="${NIX_CONFIG:+$NIX_CONFIG$'\n'}experimental-features = nix-command flakes"

# ~/.pi/agent/settings.json is a symlink into this repo and pi writes its own
# changelog bookkeeping into it. The clean filter compares the file without that
# field, so the write never turns into a diff. `required` makes a missing filter
# script fail loudly instead of silently letting the state back in.
configure_pi_settings_filter() {
  local filter_script="$repo_dir/scripts/normalize-pi-settings.py"
  [[ -x "$filter_script" ]] || {
    echo "Missing or non-executable filter script: $filter_script" >&2
    return 1
  }

  git -C "$repo_dir" config --local filter.pi-runtime-state.clean "$filter_script"
  git -C "$repo_dir" config --local filter.pi-runtime-state.smudge cat
  git -C "$repo_dir" config --local filter.pi-runtime-state.required true
}

# flake.nix is the single source of truth for who this config is for.
username="$(sed -nE 's/^[[:space:]]*username = "([^"]+)";.*/\1/p' "$repo_dir/flake.nix" | head -n1)"
[[ -n "$username" ]] || { echo "Could not read 'username = ' from flake.nix" >&2; exit 1; }
[[ "$username" == "$(id -un)" ]] || {
  echo "flake.nix is configured for $username, but you are $(id -un)" >&2
  exit 1
}

# pi never reads its proxy credential from this repo: the managed models.json
# resolves it at runtime from the machine-local file below. A machine whose
# models.json still holds the literal key would lose it the moment Home Manager
# replaces that file, so carry the key across first. Idempotent, and it never
# writes the key anywhere the repo or the Nix store can reach.
seed_pi_proxy_key() {
  local key_file="$HOME/.pi/agent/cliproxyapi.local"
  local live_models="$HOME/.pi/agent/models.json"

  if [[ -s "$key_file" ]]; then
    return 0
  fi

  # Only a literal value is a key. "$VAR" and "!command" forms are references,
  # which is what the managed file itself contains.
  local key=""
  if [[ -f "$live_models" ]]; then
    key="$(sed -nE 's/.*"apiKey"[[:space:]]*:[[:space:]]*"([^"$!][^"]*)".*/\1/p' \
      "$live_models" | head -n1)"
  fi

  if [[ -z "$key" ]]; then
    cat >&2 <<EOF
Warning: no pi proxy credential available.
  $key_file is missing or empty, and
  $live_models holds no literal key to copy from.
  Write the cliproxyapi key into that file (it is created mode 0600) or pi
  cannot reach the proxy; it will fail with "Failed to resolve API key".
  Continuing with the rest of the switch.
EOF
    return 0
  fi

  mkdir -p -- "$(dirname -- "$key_file")"
  (umask 077; printf '%s\n' "$key" > "$key_file")
  chmod 600 "$key_file"
  echo "Seeded $key_file from $live_models (mode 0600, outside this repo)."
}

# --check must be side-effect free. --appearance replaces no config file, so it
# needs neither the credential nor the filter.
if [[ -z "${check_only:-}" && -z "${appearance_only:-}" ]]; then
  seed_pi_proxy_key
fi
if [[ -z "${check_only:-}" ]]; then
  configure_pi_settings_filter
fi

if [[ -n "${appearance_only:-}" ]]; then
  exec nix run "$repo_dir#appearance"
fi

if [[ -n "${check_only:-}" ]]; then
  nix flake check --no-build "$repo_dir"
  nix build --no-link --dry-run \
    "$repo_dir#homeConfigurations.${username}.activationPackage"
  exit 0
fi

# home.nix resolves every config symlink through ~/.dotfiles, so this has to
# exist before the switch or the links point nowhere.
if [[ -e "$dotfiles_link" && ! -L "$dotfiles_link" ]]; then
  echo "$dotfiles_link exists and is not a symlink; move it aside first" >&2
  exit 1
fi
ln -sfn -- "$repo_dir" "$dotfiles_link"

nix run "$repo_dir#home-manager" -- switch -b bak --flake "$repo_dir#$username"
