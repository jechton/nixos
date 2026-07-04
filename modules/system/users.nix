{
  config,
  lib,
  ...
}: let
  cfg = config.custom.users;
in {
  options.custom.users = {
    enable = lib.mkEnableOption "primary user account";
    username = lib.mkOption {
      type = lib.types.str;
      description = "Login name";
    };
    displayName = lib.mkOption {
      type = lib.types.str;
      description = "Full display name";
    };
    gitEmail = lib.mkOption {
      type = lib.types.str;
      description = "Email address for git commits";
    };
  };

  config = lib.mkIf cfg.enable {
    users.mutableUsers = false;
    users.users.${cfg.username} = {
      isNormalUser = true;
      description = cfg.displayName;
      extraGroups = ["wheel" "networkmanager" "video" "audio"];
      hashedPasswordFile = config.age.secrets.user-password.path;
    };

    systemd.tmpfiles.rules = [
      "d /home/${cfg.username}              0700 ${cfg.username} users -"
      "d /persist/home/${cfg.username}      0700 ${cfg.username} users -"
    ];

    home-manager.users.${cfg.username} = {
      imports = [../../home/${cfg.username}/default.nix];
      _module.args = {
        inherit (cfg) username;
        inherit (cfg) displayName;
        inherit (cfg) gitEmail;
      };
    };
  };
}
