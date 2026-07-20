{ lib, config, ... }:
let
  inherit (lib.lists) any;

  hasTouchpad = any (m: (m.base_class.name or "") == "touchpad") (
    config.hardware.facter.report.hardware.mouse or [ ]
  );
in
{
  services.libinput = {
    enable = true;
    mouse = {
      accelProfile = "flat";
      accelSpeed = "0";
    };
    touchpad = lib.mkIf hasTouchpad {
      naturalScrolling = true;
      tapping = true;
      clickMethod = "clickfinger";
      disableWhileTyping = true;
    };
  };
}
