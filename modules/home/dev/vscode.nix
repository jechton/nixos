{ pkgs, ... }:
{
  programs.vscode = {
    enable = true;
    package = pkgs.vscode-fhs;
  };

  home.persistence."/persist".directories = [
    ".vscode"
    ".config/Code"
  ];
}
