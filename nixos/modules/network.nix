{ config, lib, pkgs, ... }:

{
  networking.hostName = "Homelab";

  # Static IP
  networking.interfaces.enp0s31f6.ipv4.addresses = [{
    address = "10.0.0.50";
    prefixLength = 24;
  }];
  networking.defaultGateway = "10.0.0.1";
  networking.nameservers = [ "" "" ];

  # Firewall - LAN and VPN only, nothing public
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 80 443 4533 6443 ];
    allowedUDPPorts = [ 8472 ];
    trustedInterfaces = [ "cni0" "flannel.1" "vxlan.calico" ];
  };
}
