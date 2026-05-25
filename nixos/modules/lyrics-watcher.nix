{ config, pkgs, lib, ... }:
{
  systemd.services.lyrics-watcher = {
    description = "Auto-fetch lyrics for new music";
    after = [ "network.target" ];
    environment = {
      PATH = lib.mkForce "/run/current-system/sw/bin";
    };
    serviceConfig = {
      Type = "oneshot";
      User = "user";
      ExecStart = "/run/current-system/sw/bin/python3 /home/Nuurvver/get_lyrics.py";
    };
  };

  systemd.paths.lyrics-watcher = {
    description = "Watch for new music files";
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathChanged = "/media/music";
      Unit = "lyrics-watcher.service";
    };
  };
}
