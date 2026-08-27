{ inputs, ... }:
{
  imports = [ inputs.helium-browser.homeModules.default ];

  # Policy enforcement lives in modules/system/packages/helium.nix: Chromium
  # only reads managed policies from a root-owned /etc path, so writing them
  # here to ~/.config would be silently ignored.
  programs.helium = {
    enable = true;

    flags = [ "--no-first-run" ];
  };

  xdg.desktopEntries = {
    # Overrides the package's own helium.desktop: with multiple profiles
    # registered, launching without --profile-directory opens the profile
    # picker instead of going straight to Default.
    helium = {
      name = "Helium";
      genericName = "Web browser";
      exec = "helium --profile-directory=Default %U";
      icon = "helium";
      terminal = false;
      categories = [
        "Network"
        "WebBrowser"
      ];
      mimeType = [
        "text/html"
        "text/xml"
        "application/xhtml+xml"
        "x-scheme-handler/http"
        "x-scheme-handler/https"
      ];
    };

    helium-work = {
      name = "Helium — Work";
      genericName = "Web browser";
      exec = "helium --profile-directory=Work %U";
      icon = "helium";
      terminal = false;
      categories = [
        "Network"
        "WebBrowser"
      ];
      mimeType = [
        "text/html"
        "text/xml"
        "application/xhtml+xml"
        "x-scheme-handler/http"
        "x-scheme-handler/https"
      ];
    };
  };

  home.persistence."/persist".directories = [ ".config/net.imput.helium" ];
}
