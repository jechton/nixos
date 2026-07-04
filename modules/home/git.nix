{
  pkgs,
  displayName,
  gitEmail,
  ...
}: {
  programs = {
    git = {
      enable = true;
      package = pkgs.gitFull;

      settings = {
        user = {
          name = displayName;
          email = gitEmail;
        };

        commit.gpgSign = true;
        user.signingKey = "4958433042447A9C2F8EE6B3A44C315F8322DC5A";
        init.defaultBranch = "main";
        push.autoSetupRemote = true;
      };
    };

    gh = {
      enable = true;
      gitCredentialHelper.enable = true;
    };

    mergiraf = {
      enable = true;
      enableGitIntegration = true;
    };

    lazygit = {
      enable = true;
      settings = {
        update.method = false;
        disableStartupPopups = true;
      };
    };
  };
  home.shellAliases.lg = "lazygit";
}
