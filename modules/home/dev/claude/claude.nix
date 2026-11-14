{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  # Skill name -> its category directory in github:mattpocock/skills.
  mattpocockSkills = {
    # keep-sorted start
    diagnosing-bugs = "engineering";
    domain-modeling = "engineering";
    grill-me = "productivity";
    grill-with-docs = "engineering";
    grilling = "productivity";
    handoff = "productivity";
    prototype = "engineering";
    research = "engineering";
    tdd = "engineering";
    wait-what = "productivity";
    writing-for-agents = "productivity";
    # keep-sorted end
  };

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
in
{
  config = lib.mkIf (!config.burrow.profiles.vm.enable) {
    # Claude Code rewrites settings.json as a plain file; overwrite it on
    # activation instead of failing on a backup collision.
    home.file."${config.home.homeDirectory}/.claude/settings.json".force = true;

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
        voice = {
          enabled = true;
          mode = "hold";
        };
        # keep-sorted end
      };

      # Written to ~/.claude/CLAUDE.md, loaded into every session: compaction
      # guidance (Claude Code reads the "Compact instructions" heading to steer
      # auto-compact and /compact) plus a distilled lazy-senior-dev rule set
      # adapted from github:DietrichGebert/ponytail (.agents/rules/ponytail.md,
      # MIT), inlined instead of running that plugin's per-session hook injection.
      context = ./context.md;

      # Every *.md under ./skills is loaded as a skill named after the file,
      # plus the mattpocock/skills directories in mattpocockSkills (sibling
      # files stay alongside SKILL.md). Those skills call each other by name,
      # so keep the upstream names.
      skills =
        lib.mapAttrs' (file: _: lib.nameValuePair (lib.removeSuffix ".md" file) (./skills + "/${file}")) (
          lib.filterAttrs (file: type: type == "regular" && lib.hasSuffix ".md" file) (
            builtins.readDir ./skills
          )
        )
        // lib.mapAttrs (
          name: category: "${inputs.mattpocock-skills}/skills/${category}/${name}"
        ) mattpocockSkills
        // {
          humanizer = "${inputs.humanizer}";
        };

      # Upstream plugins used as-is: their repo (or subdirectory) is the plugin.
      # i-have-adhd with its time-estimate rules removed (the estimates are often wrong).
      plugins.i-have-adhd =
        let
          skillMd = pkgs.writeText "SKILL.md" (
            lib.replaceStrings
              [
                "give specific time estimates, "
                "Five facts"
                "4. Time estimates feel uniform. \"A bit of work\" and \"a few hours\" register the same. Vague estimates fail.\n5. Dopamine"
                "### 6. Give specific time estimates\n\nVague estimates fail. Ballpark in concrete units.\n\nBad: \"This will take some work.\"\nGood: \"About 15 minutes if tests already cover this. An afternoon if not.\"\n\n"
                "### 7. "
                "### 8. "
                "### 9. "
                "### 10. "
                ",\" point time estimates at whoever executes the steps."
              ]
              [
                ""
                "Four facts"
                "4. Dopamine"
                ""
                "### 6. "
                "### 7. "
                "### 8. "
                "### 9. "
                ".\""
              ]
              (builtins.readFile "${inputs.i-have-adhd}/skills/i-have-adhd/SKILL.md")
          );
        in
        pkgs.runCommand "i-have-adhd-plugin" { } ''
          cp -r ${inputs.i-have-adhd} "$out"
          chmod -R u+w "$out"
          cp ${skillMd} "$out/skills/i-have-adhd/SKILL.md"
        '';
      plugins.impeccable = "${inputs.impeccable}/plugin";

      # Anthropic's /commit and /commit-and-push slash commands, amended to
      # stage only the changes relevant to the task (same rule as the
      # stage-my-changes skill, so a commit doesn't sweep up unrelated
      # uncommitted edits) and to include any text passed after the command
      # (e.g. a Jira smart commit) in the message, plus a /commit-push command derived from /commit's
      # text (so it tracks upstream if that command's context/task changes)
      # with push added, layered into the same plugin so it shares the
      # commit-commands namespace.
      plugins.commit-commands =
        let
          stagingClause = " Stage only the changes relevant to this task; if the working tree has unrelated uncommitted edits, leave them unstaged (use `git add -p` for a file that mixes both).";
          argumentsClause = " If the user passed text after the command (`$ARGUMENTS`), include it verbatim in the commit message, on its own line at the end of the body.";

          commitMdUpstream = builtins.readFile "${inputs.claude-plugins-official}/plugins/commit-commands/commands/commit.md";
          commitMdText =
            lib.replaceStrings
              [
                "Based on the above changes, create a single git commit."
                "Stage and create the commit using a single message."
              ]
              [
                "Based on the above changes, create a single git commit.${stagingClause}${argumentsClause}"
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
          cp -r ${inputs.claude-plugins-official}/plugins/commit-commands "$out"
          chmod -R u+w "$out"
          cp ${commitMd} "$out/commands/commit.md"
          cp ${commitPushMd} "$out/commands/commit-push.md"
        '';
    };

    home.packages = [
      # Separate login, history and state under ~/.claude-work; config is shared
      # by symlinking the home-manager-managed files from ~/.claude.
      (pkgs.writeShellScriptBin "claude-work" ''
        work="$HOME/.claude-work"
        mkdir -p "$work/plugins"
        for f in CLAUDE.md settings.json claude-statusline .i-have-adhd-always skills; do
          ln -sfn "$HOME/.claude/$f" "$work/$f"
        done
        # Plugin installs and marketplaces; plugins/store and plugins/synced stay per-account.
        for f in data marketplaces known_marketplaces.json; do
          ln -sfn "$HOME/.claude/plugins/$f" "$work/plugins/$f"
        done
        CLAUDE_CONFIG_DIR="$work" exec claude "$@"
      '')
      # keep-sorted start
      inputs.claude-desktop.packages.${pkgs.stdenv.hostPlatform.system}.claude-desktop
      pkgs.ast-grep
      # impeccable's URL scanning only auto-detects Chrome, Chromium, Edge and Brave.
      pkgs.chromium
      pkgs.fastmod
      pkgs.rtk
      pkgs.sox
      # keep-sorted end
    ];

    home.file.".claude/claude-statusline" = {
      source = "${statusline}/bin/claude-statusline";
      executable = true;
    };

    # Opts in to the i-have-adhd SessionStart hook injecting its ruleset every session.
    home.file.".claude/.i-have-adhd-always".text = "";

    home.persistence."/persist" = {
      directories = [
        ".claude"
        ".claude-work"
        ".config/Claude" # Claude Desktop login session and app state
        "Claude" # Claude Desktop artifacts and scheduled tasks
      ];
      files = [ ".claude.json" ];
    };
  };
}
