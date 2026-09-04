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

# flake.nix is the single source of truth for who this config is for.
username="$(sed -nE 's/^[[:space:]]*username = "([^"]+)";.*/\1/p' "$repo_dir/flake.nix" | head -n1)"
[[ -n "$username" ]] || { echo "Could not read 'username = ' from flake.nix" >&2; exit 1; }
[[ "$username" == "$(id -un)" ]] || {
  echo "flake.nix is configured for $username, but you are $(id -un)" >&2
  exit 1
}

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
