{pkgs, ...}: {
  nixpkgs.config.allowUnfree = true;

  # /root is a read-only btrfs subvolume boundary after rollback; the nix
  # daemon needs a writable cache dir, so redirect it to the persisted /var/lib.
  systemd.services.nix-daemon.environment.XDG_CACHE_HOME = "/var/lib";

  nix = {
    package = pkgs.lixPackageSets.stable.lix;
    settings = {
      experimental-features = ["nix-command" "flakes"];
      trusted-users = ["root" "@wheel"];

      max-substitution-jobs = 128;
      http-connections = 128;
      max-jobs = "auto";

      substituters = [
        # keep-sorted start
        "https://attic.xuyh0120.win/lantian" # cachyos kernel
        "https://cache.nixos.org"
        "https://niri.cachix.org"
        "https://nix-community.cachix.org"
        "https://noctalia.cachix.org"
        # keep-sorted end
      ];

      trusted-public-keys = [
        # keep-sorted start
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
        "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
        # keep-sorted end
      ];

      auto-optimise-store = true;
      accept-flake-config = true;
      warn-dirty = false;
    };
  };

  documentation = {
    enable = true;
    doc.enable = false;
    man.enable = true;
    dev.enable = false;
    info.enable = false;
    nixos.enable = false;
  };

  programs = {
    nh = {
      enable = true;
      clean.enable = true;
      flake = "/etc/nixos";
    };
    nix-ld.enable = true;
  };
}
