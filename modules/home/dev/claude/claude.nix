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
      autoUpdates = false;
      effortLevel = "medium";
      hooks.Notification = [
        {
          matcher = "permission_prompt";
          hooks = [
            {
              type = "command";
              command = ''
                msg=$(sed -n 's/.*"message":"\([^"]*\)".*/\1/p')
                ${pkgs.libnotify}/bin/notify-send "Claude Code" "''${msg:-Permission requested}" 2>/dev/null || true
              '';
            }
          ];
        }
      ];
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
      includeCoAuthoredBy = false;
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
      outputStyle = "Concise";
      permissions = {
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
      # The built-in OS notification channel is all-or-nothing across notification
      # types, so it's disabled here and permission prompts get their own desktop
      # notification via a hook scoped to just that type, leaving out idle_prompt
      # ("Claude is waiting for your input").
      preferredNotifChannel = "notifications_disabled";
      statusLine = {
        type = "command";
        command = "$HOME/.claude/claude-statusline";
        padding = 0;
      };
      # keep-sorted end
    };

    # Loaded on demand instead of always in context: tool-selection guide for
    # the structural search/rewrite tools plus the rtk meta commands. Covers
    # what `rtk init` puts in RTK.md, and more.
    skills.cli-tools = ./cli-tools-skill.md;

    # Anthropic's /commit and /commit-and-push slash commands, linked out of
    # the claude-code repo's plugins/ directory.
    plugins.commit-commands = "${inputs.claude-code}/plugins/commit-commands";
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
