{ config, lib, pkgs, ... }:

{
  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # nh
  programs.nh = {
    enable = true;
    clean.enable = true;
    flake = "/path/to/your/flake";
  };

  system.stateVersion = "25.05";
}
