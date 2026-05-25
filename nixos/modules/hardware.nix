{ config, lib, pkgs, ... }:

{
  # Intel Quick Sync
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vaapiVdpau
      libvdpau-va-gl
    ];
  };

  # Timezone and locale
  time.timeZone = "America/Argentina/Buenos_Aires";
  i18n.defaultLocale = "en_US.UTF-8";

  # Microcode updates
  hardware.cpu.intel.updateMicrocode = true;

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Additional drives
  fileSystems."/var/lib/k8s" = {
    device = "/dev/disk/by-uuid/2d443daa-b436-4b1a-a857-4205d9784c1d";
    fsType = "ext4";
    options = [ "defaults" "nofail" ];
  };

  fileSystems."/media" = {
    device = "/dev/disk/by-uuid/4bd454fb-e1d2-4c69-b4cd-79d3350d41cf";
    fsType = "ext4";
    options = [ "defaults" "nofail" ];
  };

  fileSystems."/data" = {
    device = "/dev/disk/by-uuid/3fc4d33c-58c8-423c-ad0e-6e7b29b7032e";
    fsType = "ext4";
    options = [ "defaults" "nofail" ];
  };
}
