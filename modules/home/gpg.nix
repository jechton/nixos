{
  config,
  pkgs,
  lib,
  ...
}:
{
  programs.gpg = {
    enable = true;
    homedir = "${config.xdg.dataHome}/gnupg";
    publicKeys = [
      {
        source = ../../keys/jeremiah.asc;
        trust = "ultimate";
      }
    ];
  };

  services.gpg-agent = {
    enable = true;
    enableSshSupport = true;
    sshKeys = [ "16C1B0800A772D63752B10A84C6127F387879305" ];
    pinentry.package = pkgs.pinentry-gnome3;
  };

  home.activation.importGpgKey = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.gnupg}/bin/gpg --import /run/agenix/gpg-key
  '';

  home.persistence."/persist".directories = [ ".local/share/gnupg" ];
}
