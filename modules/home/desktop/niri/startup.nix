{
  programs.niri.settings.spawn-at-startup = [
    { command = [ "noctalia" ]; }
    { command = [ "signal-desktop" ]; }
    { command = [ "telegram-desktop" ]; }
    { command = [ "slack" ]; }
  ];
}
