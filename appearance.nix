# The single source of truth for appearance and input method.
#
# Shaped exactly like Home Manager's `dconf.settings`, so it feeds two consumers
# without either restating a key:
#   - home.nix, as `dconf.settings`, applied on every switch.
#   - flake.nix, as `packages.appearance`, a standalone `dconf load` for
#     applying just this without a full Home Manager generation.
#
# `hmLib` is Home Manager's `lib.hm`.
{ hmLib }:

{
  "org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    cursor-theme = "WhiteSur-cursors";
    gtk-theme = "MacTahoe-Dark";
    icon-theme = "WhiteSur";
  };

  # Fcitx5 owns the Vietnamese input method. GNOME only needs the US layout.
  "org/gnome/desktop/input-sources".sources = map hmLib.gvariant.mkTuple [
    [ "xkb" "us" ]
  ];

  # Leave Super+space and Shift+Super+space for Fcitx5.
  "org/gnome/desktop/wm/keybindings" = {
    switch-input-source = [ ];
    switch-input-source-backward = [ ];
  };

  # Right-side floating dock. Transparency follows the Shell theme (glass)
  # instead of a flat custom color; Blur My Shell blurs behind it.
  # Only dash-to-dock is enabled: ubuntu-dock is the same fork and enabling
  # both breaks the overview (Super search) with DockManager crashes.
  "org/gnome/shell".enabled-extensions = [
    "blur-my-shell@aunetx"
    "dash-to-dock@micxgx.gmail.com"
    "topbar-all-monitors@fa8i.github.io"
    # Tray icon host: without it Fcitx5 Lotus has nowhere to draw.
    "ubuntu-appindicators@ubuntu.com"
    "user-theme@gnome-shell-extensions.gcampax.github.com"
  ];
  "org/gnome/shell/extensions/dash-to-dock" = {
    always-center-icons = true;
    apply-custom-theme = false;
    autohide = false;
    click-action = "previews";
    custom-background-color = false;
    custom-theme-shrink = true;
    dash-max-icon-size = 50;
    dock-fixed = true;
    dock-position = "RIGHT";
    extend-height = false;
    force-straight-corner = false;
    hot-keys = false;
    icon-size-fixed = true;
    intellihide = false;
    isolate-monitors = false;
    preview-size-scale = 0.36;
    show-windows-preview = true;
    transparency-mode = "DEFAULT";
  };

  "org/gnome/shell/extensions/user-theme".name = "MacTahoe-Dark";

  # Blur My Shell settings recommended by the MacTahoe author for the glass
  # look. The extension is installed per-user (see bootstrap below, not Nix)
  # because it must match the distro's GNOME Shell; these keys apply live.
  "org/gnome/shell/extensions/blur-my-shell/panel".blur = false;
  "org/gnome/shell/extensions/blur-my-shell/applications" = {
    blur = true;
    opacity = 255;
    sigma = 50;
  };
  "org/gnome/shell/extensions/blur-my-shell/dash-to-dock" = {
    blur = true;
    brightness = 1.0;
    static-blur = false;
  };
  "org/gnome/shell/extensions/blur-my-shell/overview" = {
    blur = true;
    style-components = 0;
  };
  "org/gnome/shell/extensions/blur-my-shell/appfolder" = {
    brightness = 1.0;
    style-dialogs = 2;
  };
}
