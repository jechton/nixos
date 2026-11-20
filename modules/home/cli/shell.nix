{
  pkgs,
  lib,
  config,
  ...
}:
let
  inherit (lib) getExe;
in
{
  home.packages = [
    # keep-sorted start
    pkgs.fastfetch
    pkgs.file
    pkgs.glow
    pkgs.gping
    pkgs.just
    pkgs.ookla-speedtest
    pkgs.pnpm
    pkgs.procs
    pkgs.trash-cli
    # keep-sorted end

    # Nix tools
    # keep-sorted start
    pkgs.nix-diff
    pkgs.nix-init
    pkgs.nix-tree
    pkgs.nurl
    # keep-sorted end
  ];

  programs = {
    fish.shellAbbrs.ns = "tv nix";

    # keep-sorted start block=yes newline_separated=yes
    aria2 = {
      enable = true;
      settings = {
        continue = true;
        max-connection-per-server = 16;
        split = 16;
        min-split-size = "1M";
        max-concurrent-downloads = 5;
        file-allocation = "falloc";
        disk-cache = "64M";
      };
    };

    bat = {
      enable = true;
      # The stylix theme's lineHighlight (base03) equals its comment color, so
      # comments on batgrep's matched lines vanish. Use base01 instead.
      config.theme = lib.mkForce "base16-stylix-hl";
      themes.base16-stylix-hl.src =
        pkgs.runCommand "base16-stylix-hl.tmTheme"
          {
            theme = config.programs.bat.themes.base16-stylix.src;
            from = config.lib.stylix.colors.withHashtag.base03;
            to = config.lib.stylix.colors.withHashtag.base01;
          }
          ''
            awk -v from="$from" -v to="$to" '
              /<key>lineHighlight<\/key>/ { hl = 1 }
              hl && /<string>/ { sub(from, to); hl = 0 }
              { print }
            ' "$theme" > $out
          '';
    };

    btop = {
      enable = true;
      settings = {
        theme_background = false;
        disks_filter = "exclude=/nix/store";
      };
    };

    direnv = {
      enable = true;
      silent = true;

      nix-direnv = {
        enable = true;
        package = pkgs.nix-direnv.override { nix = config.nix.package; };
      };

      config = {
        global = {
          load_dotenv = true;
          hide_env_diff = true;
          warn_timeout = "1m";
        };
      };

      # store direnv layouts in cache instead of scattering .direnv/ in project dirs
      # https://github.com/direnv/direnv/wiki/Customizing-cache-location#hashed-directories
      stdlib = ''
        : ''${XDG_CACHE_HOME:=$HOME/.cache}
        declare -A direnv_layout_dirs

        direnv_layout_dir() {
          echo "''${direnv_layout_dirs[$PWD]:=$(
            echo -n "$XDG_CACHE_HOME"/direnv/layouts/
            echo -n "$PWD" | sha1sum | cut -d ' ' -f 1
          )}"
        }
      '';
    };

    ghostty = {
      enable = true;
      settings = {
        # keep-sorted start block=yes
        copy-on-select = "clipboard";
        cursor-invert-fg-bg = true;
        cursor-style = "bar";
        # Iosevka's default glyphs for ambiguous-width symbols are the WWID
        # variant, sized for double-width CJK-adjacent cells; their ink overflows
        # a single terminal cell and overlaps the next character. NWID selects the
        # properly narrow glyphs.
        font-feature = "+NWID";
        keybind = [
          "alt+enter=new_split:right"
          "alt+shift+enter=new_split:down"
          "alt+w=close_surface"
          "alt+shift+left=goto_split:left"
          "alt+shift+right=goto_split:right"
          "alt+up=goto_split:top"
          "alt+down=goto_split:bottom"
          "alt+shift+z=toggle_split_zoom"
          "alt+shift+equal=equalize_splits"
        ];
        mouse-hide-while-typing = true;
        quit-after-last-window-closed = true;
        # home-manager's ghostty module already sets up fish shell integration
        shell-integration-features = "ssh-env";
        unfocused-split-opacity = 0.85;
        window-inherit-working-directory = true;
        window-padding-balance = true;
        # keep-sorted end
      };
    };

    lazydocker.enable = !config.burrow.profiles.vm.enable;

    nix-search-tv.enable = true;

    superfile = {
      settings.theme = "stylix";
      themes.stylix =
        let
          inherit (config.lib.stylix.colors.withHashtag)
            base00
            base01
            base03
            base04
            base05
            base08
            base0B
            base0C
            base0D
            base0E
            ;
        in
        {
          code_syntax_highlight = "catppuccin-mocha";

          full_screen_fg = base04;
          full_screen_bg = base00;

          gradient_color = [
            base0D
            base0E
          ];
          directory_icon_color = "";

          file_panel_fg = base04;
          file_panel_bg = base00;
          file_panel_border = base03;
          file_panel_border_active = base0D;
          file_panel_top_directory_icon = base0B;
          file_panel_top_path = base0D;
          file_panel_item_selected_fg = base0C;
          file_panel_item_selected_bg = base00;

          footer_fg = base04;
          footer_bg = base00;
          footer_border = base03;
          footer_border_active = base0B;

          sidebar_fg = base04;
          sidebar_bg = base00;
          sidebar_title = base0C;
          sidebar_border = base00;
          sidebar_border_active = base08;
          sidebar_item_selected_fg = base0C;
          sidebar_item_selected_bg = base00;
          sidebar_divider = base03;

          modal_fg = base04;
          modal_bg = base00;
          modal_border_active = base03;
          modal_cancel_fg = base01;
          modal_cancel_bg = base08;
          modal_confirm_fg = base01;
          modal_confirm_bg = base0C;

          help_menu_hotkey = base0C;
          help_menu_title = base08;

          cursor = base05;
          correct = base0B;
          error = base08;
          hint = base0C;
          cancel = base08;
        };
    };

    television.channels.nix-search-tv.metadata.name = lib.mkForce "nix";

    vivid.enable = true;
    # keep-sorted end
  };

  # Extra batpipe viewers for file types bat would show as plain text or raw
  # bytes. Matching is by lowercased file name; $1 is the file in each command.
  # lazy: extension globs only, no content sniffing. Upgrade path: test
  # `file --mime-type` in the supports function.
  xdg.configFile."batpipe/viewers.d/viewers.sh".text =
    let
      viewers = [
        {
          name = "glow";
          globs = [ "*.md" ];
          cmd = ''CLICOLOR_FORCE=1 ${getExe pkgs.glow} -- "$1"'';
        }
        {
          name = "pdf";
          globs = [ "*.pdf" ];
          cmd = ''${lib.getExe' pkgs.poppler-utils "pdftotext"} -layout -- "$1" -'';
        }
        {
          name = "image";
          globs = [
            "*.avif"
            "*.bmp"
            "*.gif"
            "*.jpeg"
            "*.jpg"
            "*.png"
            "*.tiff"
            "*.webp"
          ];
          cmd = ''
            ${getExe pkgs.chafa} -- "$1"
            ${getExe pkgs.exiftool} -- "$1"
          '';
        }
        {
          name = "json";
          globs = [ "*.json" ];
          cmd = ''${getExe pkgs.jq} -C . "$1"'';
        }
        {
          name = "media";
          globs = [
            "*.flac"
            "*.m4a"
            "*.mkv"
            "*.mov"
            "*.mp3"
            "*.mp4"
            "*.ogg"
            "*.opus"
            "*.wav"
            "*.webm"
          ];
          cmd = ''${lib.getExe' pkgs.ffmpeg "ffprobe"} -hide_banner -- "$1" 2>&1'';
        }
        {
          name = "archive";
          globs = [
            "*.7z"
            "*.rar"
            "*.tar.zst"
            "*.tzst"
          ];
          cmd = ''${lib.getExe' pkgs.libarchive "bsdtar"} -tvf "$1"'';
        }
        {
          name = "sqlite";
          globs = [
            "*.db"
            "*.sqlite"
            "*.sqlite3"
          ];
          cmd = ''${getExe pkgs.sqlite} "$1" .schema'';
        }
        {
          name = "csv";
          globs = [ "*.csv" ];
          cmd = ''${lib.getExe' pkgs.csvkit "csvlook"} --no-inference "$1"'';
        }
        {
          name = "tsv";
          globs = [ "*.tsv" ];
          cmd = ''${lib.getExe' pkgs.csvkit "csvlook"} --no-inference --tabs "$1"'';
        }
        {
          name = "document";
          globs = [
            "*.docx"
            "*.epub"
            "*.odt"
          ];
          cmd = ''${getExe pkgs.pandoc} -t plain -- "$1"'';
        }
        {
          name = "hex";
          globs = [
            "*.bin"
            "*.dll"
            "*.elf"
            "*.exe"
            "*.o"
            "*.so"
          ];
          cmd = ''${getExe pkgs.hexyl} -n 4KiB -- "$1"'';
        }
      ];
      mkViewer = v: ''
        BATPIPE_VIEWERS+=("${v.name}")

        viewer_${v.name}_supports() {
          case "''${1,,}" in
            ${lib.concatStringsSep "|" v.globs}) return 0 ;;
          esac
          return 1
        }

        viewer_${v.name}_process() {
          ${v.cmd}
        }

      '';
    in
    lib.concatMapStrings mkViewer viewers;

  home.persistence."/persist".directories = [
    ".cache/direnv"
    ".cache/nix"
    ".cache/tealdeer"
    ".local/share/direnv"
    ".local/share/fish"
    ".local/share/superfile"
    ".local/share/zoxide"
    ".local/state/superfile"
  ];
}
