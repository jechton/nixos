{
  lib,
  pkgs,
  config,
  ...
}:
{
  # put ghostty's terminfo on hosts running sshd, so ssh-ing in from a
  # ghostty client doesn't hit an "unknown terminal type" error
  config = lib.mkIf config.services.openssh.enable {
    environment.systemPackages = [ pkgs.ghostty.terminfo ];
  };
}
