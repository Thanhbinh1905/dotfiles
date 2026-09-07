{ config, lib, pkgs, username, ... }:

let
  # bootstrap.sh links this repo to ~/.dotfiles so the flake stays path-independent.
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  link = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";

  # Select the workstation pieces to install and link. Defaults reproduce the
  # current machine; set a feature to false for a leaner setup.
  features = {
    gui = true;
    inputMethod = true;
    ghostty = true;
    herdr = true;
    shell = true;
    agentConfigs = true;
    developerTools = true;
  };

  userThemeExtension = "user-theme@gnome-shell-extensions.gcampax.github.com";
  # Lotus's Ubuntu + GNOME + X11 guide requires these session variables.
  inputMethodSessionVariables = {
    GLFW_IM_MODULE = "ibus";
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
    SDL_IM_MODULE = "fcitx";
    XMODIFIERS = "@im=fcitx";
  };

  # WhiteSur detects the Shell version while building. The Nix sandbox has no
  # gnome-shell binary, so upstream otherwise falls back to GNOME 48 CSS.
  gnomeShellForWhiteSur = pkgs.writeShellScriptBin "gnome-shell" ''
    echo "GNOME Shell 46.0"
  '';
  whiteSurGtkTheme = pkgs.whitesur-gtk-theme.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ gnomeShellForWhiteSur ];
  });

  whiteSurTheme = pkgs.runCommand "workspace-whitesur-dark-solid" { } ''
    mkdir -p "$out"
    # WhiteSur-Dark-solid contains relative links to shared WhiteSur-Dark
    # assets. Dereference them so the standalone theme does not contain
    # links to files outside its own Nix store output.
    cp -RL ${whiteSurGtkTheme}/share/themes/WhiteSur-Dark-solid/. "$out/"
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
  home.packages =
    with pkgs;
    (lib.optionals features.developerTools [
      cargo
      curl
      docker-buildx
      docker-client
      docker-compose
      fd
      fzf
      gh
    ])
    ++ lib.optionals features.ghostty [ ghostty ]
    ++ lib.optionals features.developerTools [
      glab
      go
    ]
    ++ lib.optionals features.herdr [ herdr ]
    ++ lib.optionals features.developerTools [
      jq
      kubectl
      lazygit
      neovim
    ]
    ++ lib.optionals features.gui [ nerd-fonts.fira-code ]
    ++ lib.optionals features.developerTools [
      pyenv
      python3
      python3Packages.pip
      ripgrep
      rustc
      tmux
      unzip
    ]
    ++ lib.optionals features.shell [ zsh ];

  fonts.fontconfig.enable = features.gui;

  i18n.inputMethod = lib.mkIf features.inputMethod {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      addons = [ pkgs.fcitx5-lotus ];
      sessionVariables = inputMethodSessionVariables;
    };
  };

  # GDM reads environment.d at login; shells source the same values from
  # hm-session-vars.sh. The explicit systemd copy also reaches GUI applications.
  systemd.user.sessionVariables = lib.mkIf features.inputMethod inputMethodSessionVariables;

  programs.git = lib.mkIf features.developerTools {
    enable = true;
    settings.user.name = "Thanhbinh1905";
    settings.user.email = "thanhbinh2003195@gmail.com";
    ignores = [ "**/.claude/settings.local.json" ];
  };

  # Config is symlinked out of the Nix store: edits land in the repo and take
  # effect immediately, with no rebuild.
  home.file =
    {
      ".config/nix/nix.conf".text = "experimental-features = nix-command flakes\n";
    }
    // lib.optionalAttrs features.shell {
      ".zshrc".source = link "home/.zshrc";
      ".oh-my-zsh".source = ohMyZsh;
    }
    // lib.optionalAttrs features.inputMethod {
      ".xinputrc".source = link "home/.xinputrc";
      ".config/fcitx5/config".source = link "home/.config/fcitx5/config";
      ".config/fcitx5/profile".source = link "home/.config/fcitx5/profile";
      ".config/fcitx5/conf/lotus.conf".source = link "home/.config/fcitx5/conf/lotus.conf";
    }
    // lib.optionalAttrs features.agentConfigs {
      # One global policy, read by all three agents. ~/.claude/CLAUDE.md cannot use
      # Claude's "@AGENTS.md" import here: that resolves to ~/.claude/AGENTS.md,
      # which nothing creates. Link the policy directly instead.
      ".claude/CLAUDE.md".source = link "home/AGENTS.md";
      ".claude/settings.json".source = link "home/.claude/settings.json";
      ".claude/statusline-command.sh".source = link "home/.claude/statusline-command.sh";

      ".codex/AGENTS.md".source = link "home/AGENTS.md";

      ".pi/agent/AGENTS.md".source = link "home/AGENTS.md";
      ".pi/agent/models.json".source = link "home/.pi/agent/models.json";
      ".pi/agent/settings.json".source = link "home/.pi/agent/settings.json";
    }
    // lib.optionalAttrs features.ghostty {
      ".config/ghostty/config".source = link "home/.config/ghostty/config";
    }
    // lib.optionalAttrs features.herdr {
      ".config/herdr/config.toml".source = link "home/.config/herdr/config.toml";
    }
    // lib.optionalAttrs features.developerTools {
      ".config/nvim".source = link "home/.config/nvim";
    }
    // lib.optionalAttrs features.gui {
      ".config/Code/User/settings.json".source = link "home/.config/Code/User/settings.json";
      ".config/xdg-desktop-portal/portals.conf".text = ''
        [preferred]
        default=gnome;gtk;
        org.freedesktop.impl.portal.FileChooser=gtk;gnome;
        org.freedesktop.impl.portal.Settings=gnome;gtk;
        org.freedesktop.impl.portal.Secret=gnome-keyring;
      '';

      # Appearance assets are pinned to the store, not editable in place.
      ".themes/WhiteSur-Dark-solid".source = whiteSurTheme;
      ".local/share/icons/WhiteSur".source =
        "${pkgs.whitesur-icon-theme}/share/icons/WhiteSur";
      ".local/share/icons/WhiteSur-cursors".source =
        "${pkgs.whitesur-cursors}/share/icons/WhiteSur-cursors";
    };

  dconf.settings = if features.gui then import ./appearance.nix { hmLib = lib.hm; } else { };

  # User Themes is the distro's own extension at /usr/share, built for this exact
  # GNOME Shell. Nixpkgs tracks a newer Shell, and its copy would land in
  # ~/.local/share, shadow the system one, and be rejected as OUT OF DATE.
  # Advisory: a missing GNOME session must not fail the whole activation.
  home.activation = lib.optionalAttrs features.gui {
    enableUserTheme = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      if [[ -x /usr/bin/gnome-extensions ]] \
        && /usr/bin/gnome-extensions info ${userThemeExtension} >/dev/null 2>&1; then
        /usr/bin/gnome-extensions enable ${userThemeExtension} || true
      else
        echo "Skipping GNOME User Themes: extension not visible to this session" >&2
      fi
    '';
  };
}
