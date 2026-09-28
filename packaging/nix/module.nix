self:
{ config, lib, pkgs, ... }:

let
  cfg = config.services.crownos;
  crownos = self.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  options.services.crownos = {
    enable = lib.mkEnableOption "the CrownOS desktop";
    startOnTty1 = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start the CrownOS session when a user logs in on the first virtual terminal.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      crownos.crownos-desktop
      pkgs.kitty
      pkgs.xwayland-satellite
      pkgs.xdg-utils
    ];
    environment.loginShellInit = lib.mkIf cfg.startOnTty1
      (builtins.readFile ../crownos-desktop/crownos-session.sh);
    services.displayManager.sessionPackages = [ crownos.crownos-desktop ];

    hardware.graphics.enable = true;
    hardware.bluetooth.enable = true;
    security.polkit.enable = true;
    services.dbus.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };
    xdg.portal = {
      enable = true;
      extraPortals = [ crownos.xdg-desktop-portal-crownos pkgs.xdg-desktop-portal-gtk ];
      configPackages = [ crownos.xdg-desktop-portal-crownos ];
    };
    systemd.packages = [ crownos.xdg-desktop-portal-crownos ];
    fonts.packages = [ pkgs.inter ];
  };
}
