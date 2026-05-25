{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    wget
    htop
    tmux
    kitty.terminfo
    fastfetch
    nnn
    unar
    beets
    (python312.withPackages (ps: with ps; [ beautifulsoup4 syncedlyrics ]))
    ffmpeg
    velero
    kubernetes-helm
    kubeseal
  ];
}
