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

  # MacTahoe detects the Shell version while building. The Nix sandbox has no
  # gnome-shell binary, so report the host version explicitly.
  gnomeShellForMacTahoe = pkgs.writeShellScriptBin "gnome-shell" ''
    echo "GNOME Shell 50.1"
  '';
  macTahoeSrc = pkgs.fetchFromGitHub {
    owner = "vinceliuice";
    repo = "MacTahoe-gtk-theme";
    rev = "2026-09-10";
    hash = "sha256-P4zevOTHd7KKLj3a9wkaY96tMFMg7iZEpz3NkbdyTwM=";
  };
  macTahoeGtkTheme = pkgs.stdenv.mkDerivation {
    pname = "mactahoe-gtk-theme";
    version = "2026-09-10";
    src = macTahoeSrc;
    nativeBuildInputs = with pkgs; [
      dialog
      glib
      jdupes
      libxml2
      sassc
      util-linux
      gnomeShellForMacTahoe
    ];
    buildInputs = [ pkgs.gnome-themes-extra ];
    postPatch = ''
      find -name "*.sh" -print0 | while IFS= read -r -d ''' file; do
        patchShebangs "$file"
      done
      # MacTahoe looks up the user home via getent, which has no entry for
      # the sandbox user. Point it at /tmp instead.
      substituteInPlace libs/lib-core.sh \
        --replace-fail 'MY_HOME=$(getent passwd "''${MY_USERNAME}" | cut -d: -f6)' 'MY_HOME=/tmp'
      # The sandbox has no sudo: `command -v sudo` fails, and with
      # `set -e` that kills the script while sourcing lib-core.sh, before
      # any output. Our invocations never need sudo (theme goes to $out,
      # libadwaita to $HOME), so neuter the lookup like nixpkgs does.
      substituteInPlace libs/lib-core.sh \
        --replace-fail 'SUDO_BIN="$(command -v sudo)"' 'SUDO_BIN="false"'
      # Upstream redirects stderr to a temp file that is deleted on exit,
      # hiding the real error when a build fails. Keep it on the build log.
      substituteInPlace libs/lib-core.sh \
        --replace-fail 'exec 2> "''${MACTAHOE_TMP_DIR}/error_log.txt"' ':'
    '';
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/themes
      # install.sh also drops the gnome-theme-switcher helper into
      # $HOME/.local, which we do not ship. Point HOME at a throwaway dir:
      # the sandbox HOME (/homeless-shelter) is not writable.
      export HOME="$(mktemp -d)"
      # Transparent (normal opacity) + blur variant: the glass look.
      ./install.sh \
        --color dark \
        --opacity normal \
        --theme default \
        --scheme standard \
        --alt normal \
        --blur \
        --dest $out/share/themes
      jdupes --quiet --link-soft --recurse $out/share
      runHook postInstall
    '';
  };

  macTahoeTheme = pkgs.runCommand "workspace-mactahoe-dark" { } ''
    mkdir -p "$out"
    # MacTahoe-Dark contains relative links to shared MacTahoe assets.
    # Dereference them so the standalone theme does not contain
    # links to files outside its own Nix store output.
    cp -RL ${macTahoeGtkTheme}/share/themes/MacTahoe-Dark/. "$out/"
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

    /* Ubuntu's Yaru shell stylesheet marks the panel background !important. */
    #panel {
      background-color: rgba(0, 0, 0, 0.15) !important;
    }
    CSS
  '';

  # The theme's GTK4 files are not enabled just by setting gtk-theme in dconf.
  # Build MacTahoe's explicit libadwaita override in the store so it stays
  # pinned and read-only like the rest of the appearance assets.
  macTahoeLibadwaita = pkgs.runCommand "workspace-mactahoe-libadwaita" {
    nativeBuildInputs = with pkgs; [
      dialog
      glib
      jdupes
      libxml2
      sassc
      util-linux
    ];
    buildInputs = [ pkgs.gnome-themes-extra ];
  } ''
    mkdir -p "$TMPDIR/source" "$TMPDIR/themes" "$out"
    cp -R ${macTahoeSrc}/. "$TMPDIR/source/"
    chmod -R u+w "$TMPDIR/source"
    cd "$TMPDIR/source"

    find -name "*.sh" -print | while IFS= read -r file; do
      patchShebangs "$file"
    done
    substituteInPlace libs/lib-core.sh \
      --replace-fail 'MY_HOME=$(getent passwd "''${MY_USERNAME}" | cut -d: -f6)' 'MY_HOME=/tmp'
    substituteInPlace libs/lib-core.sh \
      --replace-fail 'SUDO_BIN="$(command -v sudo)"' 'SUDO_BIN="false"'
    # Upstream redirects stderr to a temp file that is deleted on exit,
    # hiding the real error when a build fails. Keep it on the build log.
    substituteInPlace libs/lib-core.sh \
      --replace-fail 'exec 2> "''${MACTAHOE_TMP_DIR}/error_log.txt"' ':'

    HOME="$out" ./install.sh \
      --dest "$TMPDIR/themes" \
      --name MacTahoe \
      --color dark \
      --opacity normal \
      --alt normal \
      --theme default \
      --scheme standard \
      --blur \
      --libadwaita

    rm -rf "$out/.local" "$out/themes"

    # On GNOME 47+ libadwaita (new recoloring API) the theme no longer emits
    # translucent window colors - its @define-color block is skipped unless
    # the pre-47 code path runs - so apps fall back to opaque stock Adwaita
    # and Blur My Shell has nothing translucent to blur behind. Restore the
    # glass by overriding the named colors with alpha, mirroring the theme's
    # own blur translucency (~75-80%). Later rules win in user gtk.css.
    cat >> "$out/.config/gtk-4.0/gtk-Dark.css" <<'CSS'

    /* Translucent libadwaita base for the glass look (repo addition). */
    @define-color window_bg_color rgba(51, 51, 51, 0.78);
    @define-color view_bg_color rgba(30, 30, 30, 0.78);
    @define-color headerbar_bg_color rgba(51, 51, 51, 0.78);
    @define-color sidebar_bg_color rgba(38, 38, 38, 0.78);
    @define-color secondary_sidebar_bg_color rgba(30, 30, 30, 0.78);
    @define-color popover_bg_color rgba(51, 51, 51, 0.88);
    @define-color dialog_bg_color rgba(51, 51, 51, 0.9);
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
  # The MacTahoe theme is delivered through the explicit home.file links below,
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
      topgrade
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

  # GNOME keyring's agent cannot unlock a passphrase key without a GUI prompt,
  # so SSH fails in Herdr panes and agents. Keys are added once per login with ssh-add.
  services.ssh-agent.enable = features.developerTools;

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
      ".config/fcitx5/conf/lotus-app-rules.conf".source = link "home/.config/fcitx5/conf/lotus-app-rules.conf";
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
      ".config/topgrade.toml".source = link "home/.config/topgrade.toml";
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
      # GTK theme follows MacTahoe (transparent blur variant);
      # icons and cursors stay on WhiteSur.
      ".themes/MacTahoe-Dark".source = macTahoeTheme;
      ".config/gtk-4.0".source = "${macTahoeLibadwaita}/.config/gtk-4.0";
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
