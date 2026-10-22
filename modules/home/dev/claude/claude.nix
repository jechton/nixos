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
  # PreToolUse hook: python is not installed, so a bare python/python3 command
  # always fails. Exit 2 blocks the call and shows stderr to Claude. Only
  # command-position matches are blocked, so `uv run python ...` passes.
  denyPython = pkgs.writeShellApplication {
    name = "claude-deny-python";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      if jq -e '.tool_input.command | test("(^|[;&|(]\\s*)python3?(\\s|$)")' > /dev/null; then
        echo "python is not installed. Use Edit/Write, sed, fastmod, jq, or 'uv run python'." >&2
        exit 2
      fi
    '';
  };
  # lazy: nixpkgs' pinned pnpmDeps hash for typescript-language-server doesn't
  # match what pnpm actually fetches; drop this override once upstream re-pins it.
  typescript-language-server = pkgs.typescript-language-server.overrideAttrs (old: {
    pnpmDeps = old.pnpmDeps.overrideAttrs (_: {
      outputHash = "sha256-xR/EF60lVBsITKgH7wCM2wHM46PFQevD51KfCENSUH4=";
    });
  });
in
{
  programs.claude-code = {
    enable = true;
    # numtide's llm-agents.nix rebuilds claude-code daily; nixpkgs-unstable
    # lags upstream by a week or more.
    package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;
    settings = {
      # keep-sorted start block=yes
      attribution = {
        commit = "";
        pr = "";
        sessionUrl = false;
      };
      # Trigger auto-compact well before the default window; long sessions
      # stay expensive even with caching once context passes ~150k tokens.
      autoCompactWindow = 150000;
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
            {
              type = "command";
              command = lib.getExe denyPython;
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
          command = "${typescript-language-server}/bin/typescript-language-server";
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
