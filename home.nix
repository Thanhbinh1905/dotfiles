{ config, lib, pkgs, username, ... }:

let
  # bootstrap.sh links this repo to ~/.dotfiles so the flake stays path-independent.
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  link = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";

  userThemeExtension = "user-theme@gnome-shell-extensions.gcampax.github.com";

  whiteSurTheme = pkgs.runCommand "workspace-whitesur-dark-solid" { } ''
    mkdir -p "$out"
    # WhiteSur-Dark-solid contains relative links to shared WhiteSur-Dark
    # assets. Dereference them so the standalone theme does not contain
    # links to files outside its own Nix store output.
    cp -RL ${pkgs.whitesur-gtk-theme}/share/themes/WhiteSur-Dark-solid/. "$out/"
    chmod -R u+w "$out"
    cat >> "$out/gnome-shell/gnome-shell.css" <<'CSS'

    /* Keep the floating dock borderless. */
    #dash .dash-background,
    #dashtodockContainer #dash .dash-background {
      border: none !important;
      box-shadow: none !important;
    }

    #dash .dash-background,
    #dashtodockContainer #dash .dash-background {
      border-radius: 16px !important;
    }
    CSS
  '';

  ohMyZsh = pkgs.runCommand "workspace-oh-my-zsh" { } ''
    mkdir -p "$out"
    cp -R ${pkgs.oh-my-zsh}/share/oh-my-zsh/. "$out/"
    chmod -R u+w "$out"
    cp -R ${./home/.oh-my-zsh-custom}/. "$out/custom/"
    chmod -R u+w "$out/custom"
    mkdir -p "$out/custom/plugins/zsh-autosuggestions"
    cp -R ${pkgs.zsh-autosuggestions}/share/zsh/plugins/zsh-autosuggestions/. \
      "$out/custom/plugins/zsh-autosuggestions/"
  '';
in
{
  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "24.11";

  # Agent CLIs (claude, codex, pi) and the Node toolchain stay outside Nix:
  # they self-update with `npm install -g`, which needs a writable prefix.
  # The WhiteSur themes are delivered through the explicit home.file links below,
  # not through the profile.
  home.packages = with pkgs; [
    cargo
    curl
    docker-buildx
    docker-client
    docker-compose
    fd
    fzf
    gh
    ghostty
    glab
    go
    herdr
    ibus
    ibus-engines.bamboo
    jq
    kubectl
    lazygit
    neovim
    nerd-fonts.fira-code
    pyenv
    python3
    python3Packages.pip
    ripgrep
    rustc
    tmux
    unzip
    zsh
  ];

  fonts.fontconfig.enable = true;

  programs.git = {
    enable = true;
    settings.user.name = "Thanhbinh1905";
    settings.user.email = "thanhbinh2003195@gmail.com";
    ignores = [ "**/.claude/settings.local.json" ];
  };

  # Config is symlinked out of the Nix store: edits land in the repo and take
  # effect immediately, with no rebuild.
  home.file = {
    ".zshrc".source = link "home/.zshrc";

    # One global policy, read by all three agents. ~/.claude/CLAUDE.md cannot use
    # Claude's "@AGENTS.md" import here: that resolves to ~/.claude/AGENTS.md,
    # which nothing creates. Link the policy directly instead.
    ".claude/CLAUDE.md".source = link "home/AGENTS.md";
    ".claude/settings.json".source = link "home/.claude/settings.json";
    ".claude/statusline-command.sh".source = link "home/.claude/statusline-command.sh";

    ".codex/AGENTS.md".source = link "home/AGENTS.md";

    ".pi/agent/AGENTS.md".source = link "home/AGENTS.md";
    ".pi/agent/settings.json".source = link "home/.pi/agent/settings.json";

    ".config/ghostty/config".source = link "home/.config/ghostty/config";
    ".config/herdr/config.toml".source = link "home/.config/herdr/config.toml";
    ".config/nvim".source = link "home/.config/nvim";
    ".config/Code/User/settings.json".source = link "home/.config/Code/User/settings.json";

    ".config/nix/nix.conf".text = "experimental-features = nix-command flakes\n";

    ".config/xdg-desktop-portal/portals.conf".text = ''
      [preferred]
      default=gnome;gtk;
      org.freedesktop.impl.portal.FileChooser=gtk;gnome;
      org.freedesktop.impl.portal.Settings=gnome;gtk;
      org.freedesktop.impl.portal.Secret=gnome-keyring;
    '';

    # Appearance and input method: pinned to the store, not editable in place.
    ".oh-my-zsh".source = ohMyZsh;

    ".themes/WhiteSur-Dark-solid".source = whiteSurTheme;
    ".local/share/icons/WhiteSur".source =
      "${pkgs.whitesur-icon-theme}/share/icons/WhiteSur";
    ".local/share/icons/WhiteSur-cursors".source =
      "${pkgs.whitesur-cursors}/share/icons/WhiteSur-cursors";
    ".local/share/ibus/component/bamboo.xml".source =
      "${pkgs.ibus-engines.bamboo}/share/ibus/component/bamboo.xml";
    ".local/share/ibus-bamboo".source =
      "${pkgs.ibus-engines.bamboo}/share/ibus-bamboo";
  };

  home.sessionVariables.IBUS_COMPONENT_PATH =
    "${config.home.homeDirectory}/.local/share/ibus/component:/usr/share/ibus/component";

  dconf.settings = import ./appearance.nix { hmLib = lib.hm; };

  # User Themes is the distro's own extension at /usr/share, built for this exact
  # GNOME Shell. Nixpkgs tracks a newer Shell, and its copy would land in
  # ~/.local/share, shadow the system one, and be rejected as OUT OF DATE.
  # Advisory: a missing GNOME session must not fail the whole activation.
  home.activation.enableUserTheme = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if [[ -x /usr/bin/gnome-extensions ]] \
      && /usr/bin/gnome-extensions info ${userThemeExtension} >/dev/null 2>&1; then
      /usr/bin/gnome-extensions enable ${userThemeExtension} || true
    else
      echo "Skipping GNOME User Themes: extension not visible to this session" >&2
    fi
  '';
}
