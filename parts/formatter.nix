{
  perSystem = {pkgs, ...}: {
    treefmt = {
      projectRootFile = "flake.nix";

      programs = {
        alejandra.enable = true;
        statix.enable = true;
        deadnix.enable = true;
        keep-sorted.enable = true;
        typos = {
          enable = true;
          configFile = "./.typos.toml";
        };
      };

      settings = {
        on-unmatched = "info";
        global.excludes = [
          ".git/*"
          "LICENSE"
          "README.md"
          "flake.lock"
          "**/*.age"
          "**/*.asc"
          "hosts/**/facter.json"
        ];

        formatter = {
          alejandra.priority = 1;
          statix.priority = 2;
          deadnix.priority = 3;
        };
      };
    };

    pre-commit.settings.hooks = {
      treefmt.enable = true;

      betterleaks = {
        enable = true;
        entry = "${pkgs.betterleaks}/bin/betterleaks git --pre-commit --verbose --staged";
        pass_filenames = false;
      };
    };
  };
}
