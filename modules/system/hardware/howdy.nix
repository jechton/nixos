{ lib, config, ... }:
let
  cfg = config.burrow.profiles;
in
{
  config = lib.mkIf cfg.laptop.enable {
    services.howdy = {
      enable = true;
      # Face match skips the password prompt; the password still works as fallback.
      control = "sufficient";
      settings.video.device_path = "/dev/v4l/by-path/pci-0000:03:00.4-usb-0:1:1.2-video-index0";
    };

    environment.persistence."/persist".directories = [ "/var/lib/howdy" ];
  };
}
