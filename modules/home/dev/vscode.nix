{ pkgs, ... }:
{
  programs.vscode = {
    enable = true;
    package = pkgs.vscode-fhs;
  };

  home.persistence."/persist" = {
    directories = [
      ".vscode"
      ".config/Code/User/extensions"
      ".config/Code/User/globalStorage"
    ];
    files = [
      ".config/Code/User/settings.json"
      ".config/Code/User/keybindings.json"
    ];
  };
}
