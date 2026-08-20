{
  programs.mise = {
    enable = true;
    globalConfig = {
      tools = {
        aube = "latest";
        uv = "latest";
        usage = "latest";
      };

      settings = {
        auto_install = true; # Automatically install missing tools when running `mise x`, `mise run`

        node = {
          compile = false; # use precompiled binaries; this box otherwise defaults to a from-source build
        };

        npm = {
          package_manager = "aube";
        };

        python = {
          compile = false; # use precompiled binaries; this box otherwise defaults to a from-source build
          uv_venv_auto = true;
        };

        trusted_config_paths = [
          "~/.config/mise"
          "~/Projects"
        ];
      };
    };
  };

  home.persistence."/persist".directories = [
    # keep-sorted start
    ".cache/uv"
    ".local/share/mise"
    # keep-sorted end
  ];
}
