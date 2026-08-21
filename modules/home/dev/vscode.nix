{ pkgs, ... }:
{
  programs.vscode = {
    enable = true;
    package = pkgs.vscode-fhs;
  };

  # Keep settings.json a normal mutable file (persisted via home.persistence
  # below) so it's editable from the UI, instead of a read-only symlink into
  # the Nix store.
  stylix.targets.vscode.enable = false;

  home.persistence."/persist".directories = [
    ".vscode"
    ".config/Code"
  ];
}
