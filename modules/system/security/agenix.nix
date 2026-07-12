{
  config,
  lib,
  ...
}: let
  cfg = config.custom.agenix;
in {
  options.custom.agenix.enable = lib.mkEnableOption "agenix secret management";

  config = lib.mkIf cfg.enable {
    age.identityPaths = ["/persist/age/key.txt"];

    age.secrets = {
      user-password = {
        file = ../../../secrets/user-password.age;
      };
      gpg-key = {
        file = ../../../secrets/gpg-key.age;
        owner = "jeremiah";
      };
    };
  };
}
