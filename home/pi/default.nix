# Standalone home-manager config for the Raspberry Pi (bunpi), which runs
# Debian with the Nix package manager, not NixOS. Only the shared shell and
# editor modules are imported: the rest of modules/home needs stylix, burrow
# options and impermanence.
{ lib, ... }:
{
  imports = [
    ../../modules/home/cli/fish.nix
    ../../modules/home/dev/helix.nix
    ../../modules/home/dev/markup.nix
    ../../modules/home/dev/nix.nix
  ];

  # No Wayland over SSH: copy through the terminal (OSC 52) instead of the
  # desktop clipboard helix.nix selects.
  programs.helix.settings.editor.clipboard-provider = lib.mkForce "termcode";

  home = {
    username = "jeremiah";
    homeDirectory = "/home/jeremiah";
    stateVersion = "26.11";
  };

  programs.home-manager.enable = true;
}
