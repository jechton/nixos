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
          signingKey = "FAE8977D92FD44FEFEBC41F7A77C4232604E70B9"; # gitleaks:allow - this is public key
        };

        # keep-sorted start block=yes

        # lazygit's diff pane is too narrow for side-by-side; this feature is
        # opted into via `delta --features=lazygit` in the lazygit pager below.
        "delta \"lazygit\"" = {
          side-by-side = false;
          line-numbers = false;
          hyperlinks = false;
        };
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
        # A raw [delta] option can't be overridden by --features, so
        # side-by-side/line-numbers live in the "defaults" feature (activated
        # here) instead, letting the lazygit diff renderer below layer its own
        # feature on top for its narrower diff pane.
        navigate = true;
        features = "defaults";
        defaults = {
          side-by-side = true;
          line-numbers = true;
        };
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
          # lazygit's diff pane is too narrow for side-by-side, so this
          # overrides it (and the line-numbers/hyperlinks clutter) via the
          # "lazygit" delta feature defined above instead of the global config.
          diffRenderers = lib.lists.singleton {
            command = lib.strings.escapeShellArgs [
              "delta"
              "--paging=never"
              "--features=defaults lazygit"
            ];
          };

          overrideGpg = true;
        };
      };
    };
  };
  home.packages = [ pkgs.meld ];

  home.persistence."/persist".directories = [ ".config/gh" ];
}
