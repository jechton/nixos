{ pkgs, ... }:
{
  services = {
    udev.packages = [ pkgs.gnome-settings-daemon ];

    gnome = {
      gnome-keyring.enable = true;
      glib-networking.enable = true;

      # ssh support is already handled by home-manager's gpg-agent (enableSshSupport = true);
      # without disabling this, both agents fight over the ssh-agent socket
      gcr-ssh-agent.enable = false;
    };
  };

  security.polkit.enable = true;
}
