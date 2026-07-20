{ pkgs, ... }: {
  nixpkgs.config = {
    allowUnfree = true;
    allowBroken = false;
    allowUnsupportedSystem = false;
    allowAliases = false;
  };

  # /root is a read-only btrfs subvolume boundary after rollback; the nix
  # daemon needs a writable cache dir, so redirect it to the persisted /var/lib.
  systemd.services.nix-daemon.environment.XDG_CACHE_HOME = "/var/lib";

  nix = {
    package = pkgs.lixPackageSets.stable.lix;
    channel.enable = false;
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
        "auto-allocate-uids"
        "cgroups"
      ];
      trusted-users = [
        "root"
        "@wheel"
      ];

      max-substitution-jobs = 128;
      http-connections = 128;
      max-jobs = "auto";
      cores = 4;

      # Free up to 20GiB whenever there is less than 5GB left.
      # this setting is in bytes, so we multiply with 1024 by 3
      min-free = 5 * 1024 * 1024 * 1024;
      max-free = 20 * 1024 * 1024 * 1024;

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
      warn-dirty = false;

      # for direnv GC roots
      keep-derivations = true;
      keep-outputs = true;

      # use xdg base directories for all the nix things
      use-xdg-base-directories = true;

      # defaults to false even with the experimental feature enabled; required
      # alongside auto-allocate-uids on lix
      # https://git.lix.systems/lix-project/lix/issues/1154
      use-cgroups = true;
      auto-allocate-uids = true;

      # avoid building on a tmpfs /tmp
      # https://github.com/NixOS/nixpkgs/issues/293114#issuecomment-2663470083
      build-dir = "/var/tmp";
    };

    # auto-optimise-store above dedupes on every build; this periodic pass
    # catches anything added before that was ever enabled
    optimise = {
      automatic = true;
      dates = [ "04:00" ];
    };
  };

  documentation = {
    enable = true;
    dev.enable = false;
    doc.enable = false;
    info.enable = false;
    man.enable = true;
    nixos.enable = false;
  };

  programs = {
    nh = {
      enable = true;
      clean.enable = true;
    };
    nix-ld.enable = true;
  };

  services.envfs.enable = true;

  environment.variables = {
    FLAKE = "/etc/nixos";
    NH_FLAKE = "/etc/nixos";
  };
}
