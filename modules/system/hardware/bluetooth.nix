{
  hardware.bluetooth = {
    enable = true;
    settings = {
      General = {
        JustWorksRepairing = "always";
        MultiProfile = "multiple";
        FastConnectable = true;
        experimental = true;
        KernelExperimental = true;
      };

      Policy = {
        AutoEnable = true;
        ReconnectAttempts = 7;
        ReconnectIntervals = "1, 2, 4, 8, 16, 32, 64";
      };
    };
  };

  boot.kernelModules = [ "btusb" ];

  services.blueman.enable = true;
}
