export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
ZSH_THEME="dracula/dracula"
plugins=(git zsh-autosuggestions)

fpath=("$HOME/.zsh/completions" $fpath)

# A persistent Herdr server can outlive the graphical login and give new panes
# stale environment variables. Recover the current graphical session.
if [[ -n "${HERDR_ENV:-}" ]] && command -v systemctl >/dev/null 2>&1; then
  while IFS='=' read -r key value; do
    case "$key" in
      DESKTOP_SESSION | DISPLAY | GDMSESSION | GNOME_DESKTOP_SESSION_ID | \
        SSH_AUTH_SOCK | WAYLAND_DISPLAY | XAUTHORITY | XDG_CURRENT_DESKTOP | \
        XDG_SESSION_DESKTOP | XDG_SESSION_TYPE)
        [[ -n "$value" ]] && export "$key=$value"
        ;;
    esac
  done < <(systemctl --user show-environment 2>/dev/null)
fi

if [[ -r "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]]; then
  source "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
fi

if [[ -r "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
fi

if [[ -d "$HOME/.nix-profile/bin" ]]; then
  export PATH="$HOME/.nix-profile/bin:$PATH"
fi

# nvm must come after the Nix profile: agent CLIs (claude, codex, pi) live in the
# nvm prefix and self-update with `npm install -g`, which needs a writable prefix.
# Nix's npm would resolve to the read-only /nix/store and fail with EACCES.
if [[ -r "$HOME/.nvm/nvm.sh" ]]; then
  export NVM_DIR="$HOME/.nvm"
  source "$NVM_DIR/nvm.sh"
  [[ -r "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"
fi

if [[ -r "$HOME/.bun/_bun" ]]; then
  source "$HOME/.bun/_bun"
fi

export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
export PATH="$BUN_INSTALL/bin:$HOME/.local/bin:$PATH"

export PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
if [[ -d "$PYENV_ROOT/bin" ]]; then
  export PATH="$PYENV_ROOT/bin:$PATH"
fi

if command -v go >/dev/null 2>&1; then
  export PATH="$(go env GOPATH)/bin:$PATH"
fi

if command -v pyenv >/dev/null 2>&1; then
  eval "$(pyenv init -)"
fi

rehash

alias pvent='source .venv/bin/activate'
alias cc='claude --dangerously-skip-permissions'
