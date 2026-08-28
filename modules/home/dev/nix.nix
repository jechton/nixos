{ pkgs, ... }:
{
  # nixd language server, shared by Helix and VS Code (nix.serverPath = "nixd")
  home.packages = [ pkgs.nixd ];

  programs.helix.languages.language = [
    {
      name = "nix";
      language-servers = [ "nixd" ];
      auto-format = true;
      formatter = {
        command = "nix";
        args = [
          "fmt"
          "--"
          "--stdin"
          "source.nix"
        ];
      };
    }
  ];
}
