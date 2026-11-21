# Standalone home-manager config for the Raspberry Pi (bunpi), which runs
# Debian with the Nix package manager, not NixOS. Only the shared shell and
# editor modules are imported: the rest of modules/home needs stylix, burrow
# options and impermanence.
{ inputs, lib, ... }:
{
  imports = [
    inputs.stylix.homeModules.stylix
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
    # Tools like uv and claude install here.
    sessionPath = [ "/home/jeremiah/.local/bin" ];
  };

  # Update the Pi from the pushed flake. --refresh skips the 1 hour flake cache
  # so a fresh push is picked up. accept-flake-config trusts the flake's extra
  # binary caches, which the Pi's Nix ignores otherwise.
  programs.fish.shellAliases.hms = "home-manager switch --flake github:jechton/nixos#pi -b bak --refresh --option accept-flake-config true";

  # Terminal-only stylix: no GUI targets. Same scheme as the laptop.
  stylix = {
    enable = true;
    autoEnable = false;
    enableReleaseChecks = false;
    polarity = "dark";
    base16Scheme = "${inputs.stylix.inputs.tinted-schemes}/base16/gruvbox-material-dark-medium.yaml";
    targets = {
      bat.enable = true;
      fish.enable = true;
      fzf.enable = true;
      helix.enable = true;
      starship.enable = true;
    };
  };

  programs.home-manager.enable = true;
}
