{
  perSystem = _: {
    treefmt = {
      projectRootFile = "flake.nix";

      programs = {
        alejandra.enable = true;
        statix.enable = true;
        deadnix.enable = true;
        keep-sorted.enable = true;
      };

      settings = {
        global.excludes = [
          ".git/*"
          "LICENSE"
          "README.md"
          "flake.lock"
        ];

        formatter = {
          alejandra.priority = 1;
          statix.priority = 2;
          deadnix.priority = 3;
        };
      };
    };

    pre-commit.settings.hooks.treefmt.enable = true;
  };
}
