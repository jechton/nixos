{ pkgs, ... }:
{
  services.printing = {
    enable = true;
    # HP hardware; gutenprint covers most everything else via driverless/IPP
    drivers = with pkgs; [
      hplip
      gutenprint
    ];
  };

  environment.systemPackages = [ pkgs.system-config-printer ];
}
