{
  description = "homelab NixOS config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  outputs = { self, nixpkgs, ... }: {
    nixosConfigurations.Homelab = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hardware-configuration.nix
        ./modules/network.nix
        ./modules/ssh.nix
        ./modules/packages.nix
        ./modules/users.nix
        ./modules/hardware.nix
        ./modules/system.nix
        ./modules/k3s.nix
        ./modules/lyrics-watcher.nix
      ];
    };
  };
}
