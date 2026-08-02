{
  lib,
  pkgs,
  displayName,
  gitEmail,
  ...
}:
{
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
        branch = {
          autosetupmerge = "true";
          sort = "committerdate";
        };
        color.ui = "auto";
        column.ui = "auto";
        commit.gpgSign = true;
        core = {
          compression = 9;
          preloadindex = true;
          whitespace = "fix,-indent-with-non-tab,trailing-space,cr-at-eol";
        };
        diff = {
          algorithm = "histogram";
          colorMoced = "plain";
          mnemonixPrefix = true;
          renames = "copy";
          interHunkContext = 10;
        };
        fetch.fsckObjects = true;
        help.autocorrect = "prompt";
        init.defaultBranch = "main";
        merge = {
          conflictstyle = "zdiff3";
          tool = "meld";
        };
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
        receive.fsckObjects = true;
        rerere = {
          enabled = true;
          autoupdate = true;
        };
        status = {
          branch = true;
          showStash = true;
        };
        tag.sort = "version.refname";
        # prevent data corruption
        transfer.fsckObjects = true;
        #keep-sorted end
      };
    };

    gh = {
      enable = true;
      gitCredentialHelper.enable = true;
      settings = {
        git_protocol = "ssh";
        prompt = "enabled";
      };
    };

    delta = {
      enable = true;
      enableGitIntegration = true;
      options = {
        navigate = true;
        side-by-side = true;
        line-numbers = true;
      };
    };

    mergiraf = {
      enable = true;
      enableGitIntegration = true;
    };

    lazygit = {
      enable = true;
      settings = {
        update.method = "never";
        disableStartupPopups = true;

        gui.nerdFontsVersion = "3";

        git = {
          # https://github.com/jesseduffield/lazygit/blob/68f3bcf53b0e19da3f7b1aaee19718605e339e8c/docs/Custom_Pagers.md#delta
          pagers = lib.lists.singleton {
            pager = lib.strings.escapeShellArgs [
              "delta"
              "--paging=never"
              "--line-numbers"
              "--hyperlinks"
              "--hyperlinks-file-link-format=lazygit-edit://{path}:{line}"
            ];
          };
        };
      };
    };
  };
  home.packages = [ pkgs.meld ];
  home.shellAliases.lg = "lazygit";

  home.persistence."/persist".directories = [ ".config/gh" ];
}
