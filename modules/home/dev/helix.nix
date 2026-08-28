{ pkgs, ... }:
{
  home.packages = [ pkgs.wl-clipboard ];

  programs.helix = {
    enable = true;
    settings = {
      editor = {
        # keep-sorted start block=yes
        auto-format = true;
        bufferline = "multiple";
        clipboard-provider = "wayland";
        color-modes = true;
        completion-trigger-len = 1;
        cursor-shape = {
          normal = "block";
          insert = "bar";
          select = "underline";
        };
        cursorcolumn = true;
        cursorline = true;
        end-of-line-diagnostics = "hint";
        file-picker.hidden = false;
        gutters = [
          "diagnostics"
          "spacer"
          "line-numbers"
          "spacer"
          "diff"
        ];
        indent-guides.render = true;
        inline-diagnostics = {
          cursor-line = "info";
          other-lines = "error";
        };
        line-number = "relative";
        lsp = {
          display-color-swatches = true;
          display-inlay-hints = true;
          display-messages = true;
          display-progress-messages = true;
        };
        mouse = true;
        scrolloff = 15;
        soft-wrap.enable = true;
        statusline = {
          left = [
            "mode"
            "spinner"
            "read-only-indicator"
            "file-modification-indicator"
          ];
          center = [ "file-name" ];
          right = [
            "diagnostics"
            "spacer"
            "version-control"
            "spacer"
            "selections"
            "spacer"
            "position"
            "spacer"
            "file-type"
          ];
          mode = {
            normal = "N 󰅨";
            insert = "I 󰏪";
            select = "S 󰒉";
          };
        };
        trim-trailing-whitespace = true;
        # keep-sorted end
      };
      keys = {
        normal = {
          "C-s" = ":write";
          "A-up" = [
            "extend_to_line_bounds"
            "delete_selection"
            "move_line_up"
            "paste_before"
          ];
          "A-down" = [
            "extend_to_line_bounds"
            "delete_selection"
            "paste_after"
          ];
        };
        insert."C-s" = [
          "normal_mode"
          ":write"
        ];
        select = {
          "A-up" = [
            "extend_to_line_bounds"
            "delete_selection"
            "move_line_up"
            "paste_before"
          ];
          "A-down" = [
            "extend_to_line_bounds"
            "delete_selection"
            "paste_after"
          ];
        };
      };
    };
  };

  home.sessionVariables.EDITOR = "hx";
}
