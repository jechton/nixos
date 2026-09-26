{
  pkgs,
  lib,
  inputs,
  ...
}:
let
  statusline = pkgs.writeShellApplication {
    name = "claude-statusline";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      git
    ];
    text = builtins.readFile ./statusline.sh;
  };
in
{
  programs.claude-code = {
    enable = true;
    # numtide's llm-agents.nix rebuilds claude-code daily; nixpkgs-unstable
    # lags upstream by a week or more.
    package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;
    settings = {
      # keep-sorted start block=yes
      advisorModel = "opus";
      attribution = {
        commit = "";
        pr = "";
        sessionUrl = false;
      };
      autoUpdates = false;
      effortLevel = "medium";
      # RTK (Rust Token Killer): rewrites Bash commands to filtered `rtk`
      # equivalents before they run, cutting command output noise from the
      # context window. `rtk hook claude` is the native PreToolUse processor,
      # so no wrapper script is needed. Replaces `rtk init`, which would patch
      # settings.json that home-manager owns.
      hooks.PreToolUse = [
        {
          matcher = "Bash";
          hooks = [
            {
              type = "command";
              command = "${lib.getExe pkgs.rtk} hook claude";
            }
          ];
        }
      ];
      lspServers = {
        python = {
          command = "${pkgs.pyright}/bin/pyright-langserver";
          args = [ "--stdio" ];
          extensionToLanguage = {
            ".py" = "python";
          };
        };
        typescript = {
          command = "${pkgs.typescript-language-server}/bin/typescript-language-server";
          args = [ "--stdio" ];
          extensionToLanguage = {
            ".ts" = "typescript";
            ".tsx" = "typescriptreact";
            ".js" = "javascript";
            ".jsx" = "javascriptreact";
          };
        };
      };
      model = "sonnet";
      outputStyle = "Concise";
      permissions = {
        allow = [
          # keep-sorted start
          "WebFetch(domain:docs.anthropic.com)"
          "WebFetch(domain:github.com)"
          "WebFetch(domain:raw.githubusercontent.com)"
          "WebFetch(domain:search.nixos.org)"
          "WebFetch(domain:wiki.nixos.org)"
          # keep-sorted end
        ];
        ask = [
          # keep-sorted start
          "Bash(git push *)"
          "Bash(kill *)"
          "Bash(pkill *)"
          "Bash(rm *)"
          # keep-sorted end
        ];
        deny = [
          "Bash(chmod -R 000 /*)"
          "Bash(chmod -R 777 /*)"
          "Bash(dd *)"
          "Bash(halt*)"
          "Bash(mkfs*)"
          "Bash(poweroff*)"
          "Bash(reboot*)"
          "Bash(rm -rf .*)"
          "Bash(rm -rf /*)"
          "Bash(rm -rf /)"
          "Bash(rm -rf ~*)"
          "Bash(shutdown*)"
          "Bash(sudo *)"
        ];
      };
      promptSuggestionEnabled = false;
      statusLine = {
        type = "command";
        command = "$HOME/.claude/claude-statusline";
        padding = 0;
      };
      # keep-sorted end
    };

    # Written to ~/.claude/CLAUDE.md, loaded into every session: compaction
    # guidance (Claude Code reads the "Compact instructions" heading to steer
    # auto-compact and /compact) plus a distilled lazy-senior-dev rule set
    # adapted from github:DietrichGebert/ponytail (.agents/rules/ponytail.md,
    # MIT), inlined instead of running that plugin's per-session hook injection.
    context = ./context.md;

    # Every *.md under ./skills is loaded as a skill named after the file.
    skills =
      lib.mapAttrs' (file: _: lib.nameValuePair (lib.removeSuffix ".md" file) (./skills + "/${file}"))
        (
          lib.filterAttrs (file: type: type == "regular" && lib.hasSuffix ".md" file) (
            builtins.readDir ./skills
          )
        );

    # Anthropic's /commit and /commit-and-push slash commands, amended to
    # stage only the changes relevant to the task (same rule as the
    # stage-my-changes skill, so a commit doesn't sweep up unrelated
    # uncommitted edits), plus a /commit-push command derived from /commit's
    # text (so it tracks upstream if that command's context/task changes)
    # with push added, layered into the same plugin so it shares the
    # commit-commands namespace.
    plugins.commit-commands =
      let
        stagingClause = " Stage only the changes relevant to this task; if the working tree has unrelated uncommitted edits, leave them unstaged (use `git add -p` for a file that mixes both).";

        commitMdUpstream = builtins.readFile "${inputs.claude-code}/plugins/commit-commands/commands/commit.md";
        commitMdText =
          lib.replaceStrings
            [
              "Based on the above changes, create a single git commit."
              "Stage and create the commit using a single message."
            ]
            [
              "Based on the above changes, create a single git commit.${stagingClause}"
              "Stage only the changes relevant to this task, then create the commit in a single message."
            ]
            commitMdUpstream;
        commitMd = pkgs.writeText "commit.md" commitMdText;

        commitPushMd = pkgs.writeText "commit-push.md" (
          lib.replaceStrings
            [
              "allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*)"
              "description: Create a git commit"
              "Based on the above changes, create a single git commit."
              "Stage only the changes relevant to this task, then create the commit in a single message."
            ]
            [
              "allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*), Bash(git push:*)"
              "description: Commit and push"
              "Based on the above changes, create a single git commit, then push the current branch to origin."
              "Stage only the changes relevant to this task, then create the commit and push in a single message."
            ]
            commitMdText
        );
      in
      pkgs.runCommand "commit-commands-plugin" { } ''
        cp -r ${inputs.claude-code}/plugins/commit-commands "$out"
        chmod -R u+w "$out"
        cp ${commitMd} "$out/commands/commit.md"
        cp ${commitPushMd} "$out/commands/commit-push.md"
      '';
  };

  home.packages = [
    # keep-sorted start
    pkgs.ast-grep
    pkgs.fastmod
    pkgs.rtk
    pkgs.semgrep
    # keep-sorted end
  ];

  home.file.".claude/claude-statusline" = {
    source = "${statusline}/bin/claude-statusline";
    executable = true;
  };

  home.persistence."/persist" = {
    directories = [ ".claude" ];
    files = [ ".claude.json" ];
  };
}
