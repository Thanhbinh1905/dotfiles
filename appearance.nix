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
    gtk-theme = "WhiteSur-Dark-solid";
    icon-theme = "WhiteSur";
  };

  "org/gnome/desktop/input-sources".sources = map hmLib.gvariant.mkTuple [
    [ "xkb" "us" ]
    [ "ibus" "Bamboo" ]
  ];

  "desktop/ibus/general" = {
    enable-by-default = false;
    engines-order = [ "Bamboo" ];
    preload-engines = [ "Bamboo" ];
    use-global-engine = true;
  };

  "org/gnome/shell/extensions/dash-to-dock" = {
    always-center-icons = true;
    apply-custom-theme = false;
    autohide = false;
    background-color = "#1c1c1e";
    background-opacity = 0.5;
    custom-background-color = true;
    custom-theme-shrink = true;
    dock-fixed = true;
    dock-position = "RIGHT";
    extend-height = false;
    force-straight-corner = false;
    intellihide = false;
    transparency-mode = "FIXED";
  };

  "org/gnome/shell/extensions/user-theme".name = "WhiteSur-Dark-solid";
}
