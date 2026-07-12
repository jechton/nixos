{
  inputs,
  username,
  ...
}: {
  imports = [
    (inputs.import-tree ../../modules/home)
    ./impermanence.nix
  ];

  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    file.".face" = {
      source = builtins.fetchurl {
        url = "https://github.com/jechton.png";
        sha256 = "sha256-Y2K+cuKp/JkgEcJv+B9JcehMGyLACuB6ubIhHH2sMgQ=";
      };
    };
  };

  programs.home-manager.enable = true;

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
  };

  # custom.home = {
  #   shell.enable = true;

  #   git = {
  #     enable = true;
  #     name = displayName;
  #     email = gitEmail;
  #   };
  # };

  home.stateVersion = "26.11";
}
