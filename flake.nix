{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    # Unstable nixpkgs with 1 week delay: https://determinate.systems/blog/nixpkgs-cooldown/
    # nixpkgs.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0.1";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # keep-sorted start block=yes
    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    impermanence = {
      url = "github:nix-community/impermanence";
      inputs = {
        home-manager.follows = "home-manager";
        nixpkgs.follows = "nixpkgs";
      };
    };
    import-tree.url = "github:denful/import-tree";
    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # keep-sorted end

    # keep-sorted start block=yes
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    helium-browser = {
      url = "github:oxcl/nix-flake-helium-browser";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
    nix-gaming.url = "github:fufexan/nix-gaming";
    nix-index-database = {
      url = "github:Mic92/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixcord = {
      url = "github:4evy/nixcord";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia-community-plugins = {
      url = "github:noctalia-dev/community-plugins";
      flake = false;
    };
    noctalia-official-plugins = {
      url = "github:noctalia-dev/official-plugins";
      flake = false;
    };
    noctalia.url = "github:noctalia-dev/noctalia-shell";
    nvf = {
      url = "github:notashelf/nvf";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };
    # keep-sorted end
  };

  # nixConfig must be literal. Keep in sync manually.
  nixConfig = {
    extra-substituters = [
      # keep-sorted start
      "https://attic.xuyh0120.win/lantian" # cachyos kernel
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://noctalia.cachix.org"
      # keep-sorted end
    ];

    extra-trusted-public-keys = [
      # keep-sorted start
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      # keep-sorted end
    ];

    extra-experimental-features = [
      "nix-command"
      "flakes"
    ];

    http-connections = 128;
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-parts,
      import-tree,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      imports = [
        # keep-sorted start
        inputs.devshell.flakeModule
        inputs.pre-commit-hooks.flakeModule
        inputs.treefmt-nix.flakeModule
        # keep-sorted end
        (import-tree ./parts)
      ];

      flake.nixosConfigurations =
        let
          mkHost =
            {
              system ? "x86_64-linux",
              hostModule,
              user ? {
                username = "jeremiah";
                displayName = "Jeremiah";
                gitEmail = "44993244+jechton@users.noreply.github.com";
              },
            }:
            nixpkgs.lib.nixosSystem {
              inherit system;
              specialArgs = { inherit inputs self; };
              modules = [
                # keep-sorted start
                inputs.agenix.nixosModules.default
                inputs.disko.nixosModules.disko
                inputs.home-manager.nixosModules.home-manager
                inputs.impermanence.nixosModules.impermanence
                # keep-sorted end

                {
                  home-manager = {
                    useGlobalPkgs = true;
                    useUserPackages = true;
                    extraSpecialArgs = { inherit inputs; };
                    verbose = true;
                    backupFileExtension = "bak";
                  };

                  burrow.users = {
                    enable = true;
                  }
                  // user;
                }

                hostModule
                (import-tree ./modules/system)
              ];
            };
        in
        {
          vm = mkHost {
            hostModule = ./hosts/vm;
          };

          floptop = mkHost {
            hostModule = ./hosts/floptop;
          };
        };
    };
}
