{ config, lib, pkgs, ... }:

{
  users.users.user = {
    isNormalUser = true;
    extraGroups = [ "wheel" "video" "render" ];
    openssh.authorizedKeys.keys = [
      "your ssh pub key"
    ];
  };
}
