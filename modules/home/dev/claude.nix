{
  programs.claude-code = {
    enable = true;
  };

  home.persistence."/persist" = {
    directories = [ ".claude" ];
    files = [ ".claude.json" ];
  };
}
