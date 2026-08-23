{
  programs.helix = {
    enable = true;
    settings = {
      editor = {
        # keep-sorted start block=yes
        auto-format = true;
        bufferline = "multiple";
        color-modes = true;
        cursor-shape = {
          normal = "block";
          insert = "bar";
          select = "underline";
        };
        cursorcolumn = true;
        cursorline = true;
        indent-guides.render = true;
        line-number = "relative";
        lsp.display-messages = true;
        soft-wrap.enable = true;
        # keep-sorted end
      };
    };
  };

  home.sessionVariables.EDITOR = "hx";
}
