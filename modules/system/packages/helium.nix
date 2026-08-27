{ inputs, ... }:
{
  imports = [ inputs.helium-browser.nixosModules.default ];

  # Chromium only loads managed policies from a root-owned /etc path, never
  # from user config, so enforcement has to happen here even though the
  # browser itself is installed via home-manager.
  programs.helium = {
    enable = true;

    policies = {
      # keep-sorted start
      AutofillAddressEnabled = false;
      AutofillCreditCardEnabled = false;
      BrowserSignin = 0;
      DefaultBrowserSettingEnabled = false;
      PasswordManagerEnabled = false;
      SyncDisabled = true;
      # keep-sorted end
    };
  };
}
