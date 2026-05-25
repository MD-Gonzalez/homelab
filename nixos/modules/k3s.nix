{ config, lib, pkgs, ... }:

{
  # k3s
  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = toString [
      "--data-dir /var/lib/k8s"
      "--disable traefik"     
      "--disable servicelb" 
      "--write-kubeconfig-mode 644"
    ];
  };
  # k3s ports - LAN and VPN only
  networking.firewall.extraInputRules = ''
    ip saddr { 10.0.0.0/24, 10.10.0.0/24 } tcp dport 6443 accept
    ip saddr { 10.0.0.0/24, 10.10.0.0/24 } udp dport 8472 accept
  '';
}
