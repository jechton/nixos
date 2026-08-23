{ lib, ... }:
let
  niriLib = import ./_lib.nix { inherit lib; };
  inherit (niriLib)
    withTitle
    withProps
    noArg
    withArg
    spawn
    ;
  hidden = niriLib.hiddenBind;

  mkDirectionalBinds =
    modifier: label:
    {
      left,
      down,
      up,
      right,
    }:
    let
      mk = direction: action: withTitle "${label} ${direction}" (noArg action);
    in
    {
      "${modifier}+Left" = mk "Left" left;
      "${modifier}+Down" = mk "Down" down;
      "${modifier}+Up" = mk "Up" up;
      "${modifier}+Right" = mk "Right" right;
      "${modifier}+H" = mk "Left" left;
      "${modifier}+J" = mk "Down" down;
      "${modifier}+K" = mk "Up" up;
      "${modifier}+L" = mk "Right" right;
    };

  mkWorkspaceNumberBinds =
    modifier: action: label:
    builtins.listToAttrs (
      map (workspace: {
        name = "${modifier}+${toString workspace}";
        value = withTitle "${label} ${toString workspace}" (withArg action workspace);
      }) (lib.range 1 9)
    );

  mkScrollBinds =
    modifier: label:
    {
      left,
      right,
      up,
      down,
    }:
    {
      "${modifier}+WheelScrollDown" = withProps (withTitle "${label} Down" (noArg down)) {
        cooldown-ms = 150;
      };
      "${modifier}+WheelScrollUp" = withProps (withTitle "${label} Up" (noArg up)) {
        cooldown-ms = 150;
      };
      "${modifier}+WheelScrollRight" = withTitle "${label} Right" (noArg right);
      "${modifier}+WheelScrollLeft" = withTitle "${label} Left" (noArg left);
    };

  noctalia =
    command:
    [
      "noctalia"
      "msg"
    ]
    ++ command;
in
{
  wayland.windowManager.niri.settings = {
    hotkey-overlay.skip-at-startup = { };

    input = {
      focus-follows-mouse = { };
      keyboard.numlock = { };

      touchpad = {
        tap = { };
        natural-scroll = { };
      };
    };

    binds = lib.mkMerge [
      # Navigation & window management
      {
        "Mod+Q" = withTitle "Close Window" (noArg "close-window");
        "Mod+T" = withTitle "Toggle Floating" (noArg "toggle-window-floating");
        "Mod+Shift+T" = withTitle "Switch Floating/Tiling Focus" (
          noArg "switch-focus-between-floating-and-tiling"
        );
        "Mod+Ctrl+F" = withTitle "Expand Column to Available Width" (
          noArg "expand-column-to-available-width"
        );
        "Mod+F" = withTitle "Maximize Column" (noArg "maximize-column");
        "Mod+Shift+F" = withTitle "Fullscreen Window" (noArg "fullscreen-window");
        "Mod+Tab" = withTitle "Focus Workspace Below" (noArg "focus-workspace-down");
        "Mod+Shift+Tab" = withTitle "Focus Workspace Above" (noArg "focus-workspace-up");

        "Mod+BracketLeft" = withTitle "Consume/Expel Window Left" (noArg "consume-or-expel-window-left");
        "Mod+BracketRight" = withTitle "Consume/Expel Window Right" (noArg "consume-or-expel-window-right");
        "Mod+R" = withTitle "Cycle Column Width" (noArg "switch-preset-column-width");
        "Mod+Shift+R" = withTitle "Cycle Column Width (Reverse)" (noArg "switch-preset-column-width-back");
        "Mod+Minus" = withTitle "Shrink Column Width" (withArg "set-column-width" "-10%");
        "Mod+Equal" = withTitle "Grow Column Width" (withArg "set-column-width" "+10%");
        "Mod+Shift+Minus" = withTitle "Shrink Window Height" (withArg "set-window-height" "-10%");
        "Mod+Shift+Equal" = withTitle "Grow Window Height" (withArg "set-window-height" "+10%");
        "Mod+C" = withTitle "Center Column" (noArg "center-column");
        "Mod+Ctrl+C" = withTitle "Center Visible Columns" (noArg "center-visible-columns");
        "Mod+G" = withTitle "Toggle Tabbed Column" (noArg "toggle-column-tabbed-display");

        "Mod+O" = withProps (withTitle "Workspace Overview" (noArg "toggle-overview")) {
          repeat = false;
        };
      }

      # System controls
      {
        "Mod+Escape" = withTitle "Open Session Management" (
          spawn (noctalia [
            "panel-toggle"
            "session"
          ])
        );
        "Ctrl+Alt+Delete" = withTitle "Open Session Management" (
          spawn (noctalia [
            "panel-toggle"
            "session"
          ])
        );
        "Mod+Ctrl+Escape" = withTitle "Lock Session" (
          spawn (noctalia [
            "session"
            "lock"
          ])
        );
        "Mod+Shift+P" = withTitle "Turn Off Monitors" (noArg "power-off-monitors");
        "Mod+S" = withTitle "Control Center" (
          spawn (noctalia [
            "panel-toggle"
            "control-center"
          ])
        );
        "Mod+Comma" = withTitle "Noctalia Settings" (spawn (noctalia [ "settings-toggle" ]));
        "Mod+Shift+W" = withTitle "Wallpaper Panel" (
          spawn (noctalia [
            "panel-toggle"
            "wallpaper"
          ])
        );
        "Mod+N" = withTitle "Clear Notification" (spawn (noctalia [ "notification-clear-active" ]));
        "Mod+Shift+N" = withTitle "Open Notifications" (
          spawn (noctalia [
            "panel-toggle"
            "control-center"
            "notifications"
          ])
        );
        "Mod+Ctrl+N" = withTitle "Toggle DND" (spawn (noctalia [ "notification-dnd-toggle" ]));
        "Mod+Slash" = withTitle "Keybind Cheatsheet" (spawn "niri-keybind-cheatsheet");

        "XF86AudioRaiseVolume" = hidden (spawn (noctalia [ "volume-up" ]));
        "XF86AudioLowerVolume" = hidden (spawn (noctalia [ "volume-down" ]));
        "XF86AudioMute" = hidden (spawn (noctalia [ "volume-mute" ]));
        "XF86AudioMicMute" = hidden (spawn (noctalia [ "mic-mute" ]));
        "XF86MonBrightnessUp" = hidden (spawn (noctalia [ "brightness-up" ]));
        "XF86MonBrightnessDown" = hidden (spawn (noctalia [ "brightness-down" ]));
        "XF86AudioPlay" = hidden (spawn [
          "playerctl"
          "play-pause"
        ]);
        "XF86AudioStop" = hidden (spawn [
          "playerctl"
          "stop"
        ]);
        "XF86AudioPrev" = hidden (spawn [
          "playerctl"
          "previous"
        ]);
        "XF86AudioNext" = hidden (spawn [
          "playerctl"
          "next"
        ]);
      }

      # Launching apps
      {
        "Mod+Return" = withTitle "Terminal" (spawn "ghostty");
        "Mod+B" = withTitle "Browser" (spawn "zen-twilight");
        "Mod+E" = withTitle "Files" (spawn "nautilus");
        "Mod+Space" = withTitle "Application Launcher" (
          spawn (noctalia [
            "panel-toggle"
            "launcher"
          ])
        );
      }

      # Clipboard
      {
        "Mod+V" = withTitle "Clipboard" (
          spawn (noctalia [
            "panel-toggle"
            "clipboard"
          ])
        );
      }

      # Capture
      {
        "Print" = withTitle "Screenshot" (noArg "screenshot");
        "Ctrl+Print" = withTitle "Screenshot Screen" (noArg "screenshot-screen");
        "Alt+Print" = withTitle "Screenshot Window" (noArg "screenshot-window");
        "Mod+Shift+S" = withTitle "Screenshot Region" (spawn (noctalia [ "screenshot-region" ]));
        "Mod+Ctrl+Shift+S" = withTitle "Screenshot Screen" (spawn (noctalia [ "screenshot-fullscreen" ]));
        "Mod+Ctrl+Print" = withTitle "OCR Region" (spawn "ocr-region");
      }

      (mkDirectionalBinds "Mod" "Focus" {
        left = "focus-column-left";
        down = "focus-window-down";
        up = "focus-window-up";
        right = "focus-column-right";
      })

      (mkDirectionalBinds "Mod+Shift" "Move" {
        left = "move-column-left";
        down = "move-window-down";
        up = "move-window-up";
        right = "move-column-right";
      })

      (mkDirectionalBinds "Mod+Ctrl" "Focus Monitor" {
        left = "focus-monitor-left";
        down = "focus-monitor-down";
        up = "focus-monitor-up";
        right = "focus-monitor-right";
      })

      (mkDirectionalBinds "Mod+Shift+Ctrl" "Move to Monitor" {
        left = "move-column-to-monitor-left";
        down = "move-column-to-monitor-down";
        up = "move-column-to-monitor-up";
        right = "move-column-to-monitor-right";
      })

      (mkScrollBinds "Mod" "Scroll Focus" {
        left = "focus-column-left";
        right = "focus-column-right";
        up = "focus-workspace-up";
        down = "focus-workspace-down";
      })

      (mkScrollBinds "Mod+Shift" "Scroll Move" {
        left = "move-column-left";
        right = "move-column-right";
        up = "move-column-to-workspace-up";
        down = "move-column-to-workspace-down";
      })

      (mkWorkspaceNumberBinds "Mod" "focus-workspace" "Focus Workspace")
      (mkWorkspaceNumberBinds "Mod+Shift" "move-column-to-workspace" "Move Column to Workspace")
    ];
  };
}
