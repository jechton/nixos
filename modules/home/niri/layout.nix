{
  programs.niri.settings = {
    layout = {
      gaps = 10;
      border.enable = false;
      focus-ring = {
        enable = true;
        width = 2;
      };
      preset-column-widths = [
        {proportion = 0.33333;}
        {proportion = 0.5;}
        {proportion = 0.66667;}
        {proportion = 1.0;}
      ];
      default-column-width.proportion = 0.5;
      always-center-single-column = true;
    };
  };
}
