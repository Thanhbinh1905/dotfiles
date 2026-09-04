{
  description = "Linux workstation setup: appearance managed, config editable in place";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { home-manager, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      username = "thanhbinh";
      lib = nixpkgs.lib;
      pkgs = nixpkgs.legacyPackages.${system};
      hmLib = home-manager.lib.hm;

      # Rendered from the same attrset home.nix hands to dconf.settings, with the
      # same serializer Home Manager uses, so no key is written twice.
      appearanceKeyfile = pkgs.writeText "appearance.dconf" (
        lib.generators.toINI {
          mkKeyValue = key: value: "${key}=${toString (hmLib.gvariant.mkValue value)}";
        } (import ./appearance.nix { inherit hmLib; })
      );
    in
    {
      homeConfigurations.${username} = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit username; };
        modules = [ ./home.nix ];
      };

      packages.${system} = {
        home-manager = home-manager.packages.${system}.home-manager;

        appearance = pkgs.writeShellApplication {
          name = "apply-appearance";
          runtimeInputs = [ pkgs.dconf ];
          text = ''
            dconf load / < ${appearanceKeyfile}

            if [[ -x /usr/bin/gnome-extensions ]]; then
              /usr/bin/gnome-extensions enable \
                user-theme@gnome-shell-extensions.gcampax.github.com || true
            fi
          '';
        };
      };
    };
}
