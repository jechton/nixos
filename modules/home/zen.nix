{inputs, ...}: let
  mkLockedAttrs = builtins.mapAttrs (_: value: {
    Value = value;
    Status = "locked";
  });
in {
  imports = [inputs.zen-browser.homeModules.twilight];

  programs.zen-browser = {
    enable = true;
    setAsDefaultBrowser = true;
    languagePacks = ["en-US"];

    policies = {
      # keep-sorted start
      AutofillAdressEnabled = false;
      AutofillCreditCardEnabled = false;
      DisableAppUpdate = true;
      DisableFeedbackCommands = true;
      DisableTelemetry = true;
      DisabledFirefoxStudies = true;
      DontCheckDefaultBrowser = true;
      NoDefaultBookmarks = true;
      OfferToSaveLogins = false;
      # keep-sorted end

      Preferences = mkLockedAttrs {
        # keep-sorted start
        "zen.tabs.vertical.right-side" = true;
        "zen.view.compact.enable-at-startup" = false;
        "zen.view.compact.toolbar-flash-popup" = true;
        "zen.welcome-screen.seen" = true;
        # keep-sorted end
      };
    };

    profiles.default = {
      isDefault = true;

      search.default = "ddg";
    };
  };

  xdg.desktopEntries = {
    zen-twilight = {
      name = "Zen Twilight";
      genericName = "Web browser";
      exec = "zen-twilight %u";
      categories = ["Network" "WebBrowser"];
      icon = "zen-twilight";
      terminal = false;
      mimeType = ["text/html" "text/xml" "application/xhtml+xml" "x-scheme-handler/http" "x-scheme-handler/https"];
    };
  };

  stylix.targets.zen-browser.profileNames = ["default"];
}
