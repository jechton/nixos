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

      ignores = [
        ".env"
        ".direnv"

        "*~"
        "*.log"
        "*.sqlite"

        "dist/"
        "node_modules/"

        "**/.claude/settings.local.json"
      ];

      settings = {
        user = {
          name = displayName;
          email = gitEmail;
          signingKey = "4958433042447A9C2F8EE6B3A44C315F8322DC5A"; # gitleaks:allow - this is public key
        };

        # keep-sorted start block=yes
        alias = {
          # keep-sorted start
          a = "add --all";
          aca = "!git add --all && git commit --amend";
          b = "branch";
          c = "commit -m";
          cl = "clone";
          co = "checkout";
          d = "diff -w";
          f = "fetch";
          fp = "fetch --prune";
          l = "log";
          pl = "pull";
          ps = "push";
          psf = "push --force-with-lease";
          r = "rebase";
          rmf = "rm -f";
          rmr = "rm -r";
          rmrf = "rm -rf";
          s = "status";
          st = "stash";
          staged = "diff --cached";
          stc = "stash clear";
          stp = "stash pop";
          stw = "stash show";
          u = "reset --";
          unstage = "reset --";
          # keep-sorted end
        };
        color.ui = "auto";
        column.ui = "auto";
        commit.gpgSign = true;
        core = {
          compression = 9;
          preloadindex = true;
        };
        diff = {
          algorithm = "histogram";
          colorMoced = "plain";
          mnemonixPrefix = true;
          renames = "copy";
          interHunkContext = 10;
        };
        help.autocorrect = "prompt";
        init.defaultBranch = "main";
        merge = {conflictstyle = "zdiff3";};
        pull.rebase = true;
        push = {
          autoSetupRemote = true;
          default = "simple";
          followTags = true;
        };
        rebase = {
          autoSquash = true;
          autoStash = true;
          missingCommitsCheck = "warn";
          updateRefs = true;
        };
        status = {
          branch = true;
          showStash = true;
        };
        tag.sort = "version.refname";
        #keep-sorted end
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
