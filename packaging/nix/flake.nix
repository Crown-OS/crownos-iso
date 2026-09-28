{
  description = "The CrownOS desktop for NixOS: packages and the services.crownos module";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Every repository the components build from. They reference each other as
    # `../<name>`, so packages.nix lays them out side by side, as in a checkout.
    crownpositor = { url = "github:Crown-OS/crownpositor"; flake = false; };
    crownbar = { url = "github:Crown-OS/crownbar"; flake = false; };
    crownotify = { url = "github:Crown-OS/crownotify"; flake = false; };
    crownpaper = { url = "github:Crown-OS/crownpaper"; flake = false; };
    crownpad = { url = "github:Crown-OS/crownpad"; flake = false; };
    crowndock = { url = "github:Crown-OS/crowndock"; flake = false; };
    crownos-home = { url = "github:Crown-OS/crownos-home"; flake = false; };
    crownos-clipboard = { url = "github:Crown-OS/crownos-clipboard"; flake = false; };
    crownos-settings = { url = "github:Crown-OS/crownos-settings"; flake = false; };
    crowndictator = { url = "github:Crown-OS/crowndictator"; flake = false; };
    crownconnect-linux = { url = "github:Crown-OS/crowncrate-linux"; flake = false; };
    fileshare-linux = { url = "github:Crown-OS/fileshare-linux"; flake = false; };
    xdg-desktop-portal-crownos = { url = "github:Crown-OS/xdg-desktop-portal-crownos"; flake = false; };
    crownshell = { url = "github:Crown-OS/crownshell"; flake = false; };
    crownuikit = { url = "github:Crown-OS/crownuikit"; flake = false; };
    crownos-config = { url = "github:Crown-OS/crownos-config"; flake = false; };
    crownos-ipc = { url = "github:Crown-OS/crownos-ipc"; flake = false; };
    crownos-protocols = { url = "github:Crown-OS/crownos-protocols"; flake = false; };
    llts-protocol = { url = "github:Crown-OS/lls-protocol"; flake = false; };
    ffsp-protocol = { url = "github:Crown-OS/ffsp-protocol"; flake = false; };
    vendor = { url = "github:Crown-OS/vendor"; flake = false; };
  };

  outputs = { self, nixpkgs, rust-overlay, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ rust-overlay.overlays.default ];
      };
      crownos = pkgs.callPackage ./packages.nix {
        sources = removeAttrs inputs [ "self" "nixpkgs" "rust-overlay" ];
      };
    in
    {
      packages.${system} = crownos // { default = crownos.crownos-desktop; };
      nixosModules.default = import ./module.nix self;
    };
}
