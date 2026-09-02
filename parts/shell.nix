{ inputs, ... }: {
  perSystem =
    {
      pkgs,
      config,
      system,
      ...
    }:
    {
      devshells.default = {
        motd = ''
          Type 'menu' to view available actions.
        '';

        env = [
          {
            name = "NIX_CONFIG";
            value = "extra-experimental-features = nix-command flakes";
          }
          {
            # Lets `nix fmt`/`nix flake check`/`nh` resolve the flake regardless of cwd.
            name = "NH_FLAKE";
            eval = "$PRJ_ROOT";
          }
        ];

        packages = [
          # keep-sorted start
          inputs.agenix.packages.${system}.default
          pkgs.mkpasswd
          #keep-sorted end
        ]
        ++ builtins.attrValues config.treefmt.build.programs;

        devshell.startup.pre-commit.text = config.pre-commit.installationScript;

        commands = [
          {
            name = "check";
            category = "sanity";
            help = "Format and verify flake evaluation validity";
            command = "nix fmt \"$PRJ_ROOT\" && nix flake check --no-build \"$PRJ_ROOT\"";
          }
          {
            name = "os-test";
            category = "system";
            help = "Dry-test the system configuration with nh";
            command = "nh os test -d always \"$@\"";
          }
          {
            name = "plugin-test";
            category = "system";
            help = "Dry-test with the local noctalia-plugins working tree (no commit/lock)";
            command = "nh os test -d always --override-input noctalia-plugins \"$HOME/Projects/noctalia-plugins\" \"$@\"";
          }
          {
            name = "sw";
            category = "system";
            help = "Build and apply system configurations with nh";
            command = "nh os switch -d always \"$@\"";
          }
          {
            name = "update";
            category = "system";
            help = "Pull upstream flake changes and commit";
            command = ''
              echo -e "Updating flake...\n"
              nix flake update --flake "$PRJ_ROOT"
              git -C "$PRJ_ROOT" add -A
              git -C "$PRJ_ROOT" commit -m "chore: update inputs"
              nh os switch -d always "$@"
            '';
          }
          {
            name = "gc";
            category = "maintenance";
            help = "Garbage collect system profile and optimize nix-store";
            command = "nh clean all -k 4 --optimise \"$@\"";
          }
          {
            name = "hash-url";
            category = "tools";
            help = "Prefetch a URL and print its SRI sha256 hash";
            command = "nix-prefetch-url \"$@\" | xargs nix hash convert --hash-algo sha256";
          }
        ];
      };
    };
}
