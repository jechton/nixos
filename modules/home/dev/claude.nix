{ pkgs, lib, ... }:
let
  statusline = pkgs.writeShellApplication {
    name = "claude-statusline";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      git
    ];
    text = builtins.readFile ./claude-statusline.sh;
  };
in
{
  programs.claude-code = {
    enable = true;
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

    # Equivalent of the RTK.md that `rtk init` drops into ~/.claude and
    # references from CLAUDE.md: files under rules/ are auto-loaded as memory,
    # so no @import line is needed. Tells the model which rtk subcommands to
    # call directly (the Bash hook only rewrites everything else).
    rules.rtk = ''
      # RTK (Rust Token Killer)

      Token-optimized CLI proxy: filters up to 90% of bash output. A PreToolUse
      hook transparently rewrites Bash commands (`git status` becomes
      `rtk git status`), so run normal commands as usual.

      Call these rtk subcommands directly, they are not rewritten:

      ```bash
      rtk gain              # token savings analytics
      rtk gain --history    # per-command usage and savings
      rtk discover          # scan history for missed opportunities
      rtk proxy <cmd>       # run a command unfiltered (debugging)
      ```
    '';
  };

  home.packages = [ pkgs.rtk ];

  home.file.".claude/claude-statusline" = {
    source = "${statusline}/bin/claude-statusline";
    executable = true;
  };

  home.persistence."/persist" = {
    directories = [ ".claude" ];
    files = [ ".claude.json" ];
  };
}
