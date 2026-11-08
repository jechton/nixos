{ config, lib, ... }:
let
  inherit (config.lib.formats.rasi) mkLiteral;
in
{
  # Menu for the dmenu-style scripts (daily-note, task, memo, keybind
  # cheatsheet). Colors come from stylix; the layout below sits on top.
  programs.rofi = {
    enable = true;
    settings.font = lib.mkForce "${config.burrow.theme.fonts.monospace.name} 13";
    theme = {
      window = {
        width = mkLiteral "45%";
        border = mkLiteral "2px";
        border-color = mkLiteral "@blue";
        padding = mkLiteral "12px";
      };
      inputbar = {
        padding = mkLiteral "0 8px 10px 8px";
        children = map mkLiteral [
          "prompt"
          "textbox-prompt-colon"
          "entry"
        ];
      };
      textbox-prompt-colon = {
        str = ": ";
        expand = false;
      };
      # Same side inset as the input bar and rows so the hint lines up with them.
      message.padding = mkLiteral "0 8px 10px 8px";
      listview.spacing = mkLiteral "2px";
      element.padding = mkLiteral "6px 8px";
      # Stylix uses the light foreground for the selected row; a subtle surface color is easier on the eyes.
      "element selected.normal" = {
        background-color = lib.mkForce (mkLiteral config.lib.stylix.colors.withHashtag.base02);
        text-color = lib.mkForce (mkLiteral config.lib.stylix.colors.withHashtag.base05);
      };
    };
  };

  # Plain rows; the selected row is highlighted above.
  stylix.targets.rofi.alternatePattern = false;
}
