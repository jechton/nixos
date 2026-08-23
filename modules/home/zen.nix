{ inputs, config, ... }:
let
  mkLockedAttrs = builtins.mapAttrs (
    _: value: {
      Value = value;
      Status = "locked";
    }
  );
in
{
  imports = [ inputs.zen-browser.homeModules.twilight ];

  programs.zen-browser = {
    enable = true;
    setAsDefaultBrowser = true;
    languagePacks = [ "en-US" ];

    policies = {
      # keep-sorted start
      AutofillAddressEnabled = false;
      AutofillCreditCardEnabled = false;
      DisableAppUpdate = true;
      DisableFeedbackCommands = true;
      DisableTelemetry = true;
      DisabledFirefoxStudies = true;
      DontCheckDefaultBrowser = true;
      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        Cryptomining = true;
        Fingerprinting = true;
        NoDefaultBookmarks = true;
        OfferToSaveLogins = false;
      };
      # keep-sorted end

      Preferences = mkLockedAttrs {
        # keep-sorted start
        "browser.aboutConfig.showWarning" = false;
        # 0 = dark. Default (2) follows the system color scheme via the
        # xdg-desktop-portal Settings signal, which niri's portal setup
        # doesn't reliably deliver; force it instead of depending on that.
        "layout.css.prefers-color-scheme.content-override" = 0;
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
      categories = [
        "Network"
        "WebBrowser"
      ];
      icon = "zen-twilight";
      terminal = false;
      mimeType = [
        "text/html"
        "text/xml"
        "application/xhtml+xml"
        "x-scheme-handler/http"
        "x-scheme-handler/https"
      ];
    };
  };

  stylix.targets.zen-browser.profileNames = [ "default" ];

  # This build reads its profile root from the legacy ~/.zen path, ignoring
  # the XDG ~/.config/zen profile this module declaratively manages.
  # Symlink the former to the latter so both resolve to the same real,
  # declaratively-managed profile.
  home.file.".zen".source = config.lib.file.mkOutOfStoreSymlink "${config.xdg.configHome}/zen";

  home.persistence."/persist".directories = [
    ".config/zen"
    ".mozilla"
  ];
}
