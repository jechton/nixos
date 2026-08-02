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
    };

    environment.persistence."/persist".directories = [ "/age" ];
  };
}
