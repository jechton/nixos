{config, ...}: let
  inherit (config.custom.users) username;
in {
  services.greetd = {
    enable = true;
    settings.initial_session = {
      command = "niri-session";
      user = username;
    };
  };

  # Runs the gnome-keyring PAM module on the greetd session so the login
  # keyring unlocks as part of autologin instead of needing a password prompt.
  security.pam.services.greetd.enableGnomeKeyring = true;
}
