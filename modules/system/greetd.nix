{ config, ... }:
let
  inherit (config.burrow.users) username;
in
{
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "niri-session";
      user = username;
    };
  };

  # Ensure impermanence's persisted-file symlinks/bind-mounts are in place
  # before niri (and anything it autostarts) can write into the ephemeral
  # $HOME — otherwise an app can race home-manager's activation and create a
  # real file where a persistence symlink was supposed to go.
  systemd.services.greetd.after = [ "home-manager-${username}.service" ];

  # Runs the gnome-keyring PAM module on the greetd session so the login
  # keyring unlocks as part of autologin instead of needing a password prompt.
  security.pam.services.greetd.enableGnomeKeyring = true;
}
