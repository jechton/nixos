{
  programs.mise = {
    enable = true;
    globalConfig = {
      tools = {
        aube = "latest";
        uv = "latest";
        usage = "latest";
      };
    };

    settings = {
      auto_install = true; # Automatically install missing tools when running `mise x`, `mise run`

      npm = {
        package_manager = "aube";
      };

      python = {
        uv_venv_auto = true;
      };

      trusted_config_paths = [
        "~/.config/mise"
        "~/Projects"
      ];
    };
  };
}
