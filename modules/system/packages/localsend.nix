{ pkgs, ... }:
{
  # Installs localsend and opens its firewall port (53317 TCP/UDP).
  programs.localsend = {
    enable = true;
    openFirewall = true;
    # The Flutter app loads libz.so.1 at runtime, which the nixpkgs wrapper
    # does not put on LD_LIBRARY_PATH.
    package = pkgs.localsend.overrideAttrs (old: {
      extraWrapProgramArgs = "--prefix LD_LIBRARY_PATH : ${pkgs.zlib}/lib ${old.extraWrapProgramArgs}";
    });
  };
}
