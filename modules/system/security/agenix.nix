{
  config,
  lib,
  ...
}:
let
  cfg = config.burrow.agenix;
in
{
  options.burrow.agenix.enable = lib.mkEnableOption "agenix secret management";

  config = lib.mkIf cfg.enable {
    age.identityPaths = [ "/persist/age/key.txt" ];

    age.secrets = {
      user-password = {
        file = ../../../secrets/user-password.age;
      };
      gpg-key = {
        file = ../../../secrets/gpg-key.age;
        owner = "jeremiah";
      };
      # Two lines: the Kimai instance URL, then an API token. Read by the
      # jechton/kimai noctalia plugin (see modules/home/desktop/noctalia.nix).
      kimai-credentials = {
        file = ../../../secrets/kimai-credentials.age;
        owner = "jeremiah";
      };
      # Two lines: the Home Assistant URL, then a long-lived access token. Read
      # by the jechton/home-assistant noctalia plugin.
      home-assistant-credentials = {
        file = ../../../secrets/home-assistant-credentials.age;
        owner = "jeremiah";
      };
      home-assistant-people-template = {
        file = ../../../secrets/home-assistant-people-template.age;
        owner = "jeremiah";
      };
    };

    environment.persistence."/persist".directories = [ "/age" ];
  };
}
