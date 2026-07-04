{
  inputs,
  username,
  ...
}: {
  imports = [
    (inputs.import-tree ../../modules/home)
    ./impermanence.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";

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
