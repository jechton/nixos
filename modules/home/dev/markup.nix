{ pkgs, ... }:
{
  # Language servers for markup and config formats, picked up by Helix off PATH.
  home.packages = [
    # keep-sorted start
    pkgs.marksman
    pkgs.taplo
    pkgs.typos-lsp
    pkgs.yaml-language-server
    # keep-sorted end
  ];

  programs.helix.languages.language = [
    {
      name = "markdown";
      language-servers = [
        "marksman"
        "typos"
      ];
    }
    {
      name = "toml";
      language-servers = [
        "taplo"
        "typos"
      ];
      auto-format = true;
    }
    {
      name = "yaml";
      language-servers = [
        "yaml-language-server"
        "typos"
      ];
    }
  ];
}
