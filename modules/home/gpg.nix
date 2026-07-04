{
  pkgs,
  lib,
  ...
}: {
  programs.gpg = {
    enable = true;
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
    sshKeys = ["CEB85009AE01B798C77C05B77CE95A716A952580"];
    pinentry.package = pkgs.pinentry-gnome3;
  };

  home.activation.importGpgKey = lib.hm.dag.entryAfter ["writeBoundary"] ''
    $DRY_RUN_CMD ${pkgs.gnupg}/bin/gpg --import /run/agenix/gpg-key
  '';
}
