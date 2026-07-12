{
  pkgs,
  lib,
  ...
}: let
  inherit (lib) getExe;

  ns = pkgs.writeShellApplication {
    name = "ns";
    runtimeInputs = [pkgs.fzf pkgs.nix-search-tv];
    text = builtins.readFile "${pkgs.nix-search-tv.src}/nixpkgs.sh";
  };

  ocrRegion = pkgs.writeShellApplication {
    name = "ocr-region";
    runtimeInputs = with pkgs; [
      coreutils
      gnused
      grim
      libnotify
      slurp
      tesseract
      wl-clipboard
    ];
    text = ''
      image="$(mktemp --suffix=.png)"
      trap 'rm -f "$image"' EXIT

      geometry="$(slurp)" || exit 0
      grim -g "$geometry" "$image"

      text="$(tesseract "$image" stdout --psm 6 2>/dev/null | sed '/^[[:space:]]*$/d')"
      if [ -n "$text" ]; then
        printf '%s' "$text" | wl-copy
        notify-send "OCR copied" "Recognized text is in the clipboard."
      else
        notify-send "OCR empty" "No text was recognized in the selected region."
      fi
    '';
  };
in {
  home = {
    packages = [
      # keep-sorted start
      pkgs.fishPlugins.autopair
      pkgs.fishPlugins.bang-bang
      pkgs.fishPlugins.bass
      pkgs.fishPlugins.fish-you-should-use
      pkgs.fishPlugins.puffer
      pkgs.fishPlugins.sponge
      # keep-sorted end

      # keep-sorted start
      pkgs.file
      pkgs.gping
      pkgs.just
      pkgs.p7zip
      pkgs.pnpm
      pkgs.procs
      pkgs.trash-cli
      pkgs.unzip
      # keep-sorted end

      # Nix tools
      # keep-sorted start block=yes
      ns
      ocrRegion
      pkgs.nix-diff
      pkgs.nix-init
      pkgs.nix-tree
      pkgs.nurl
      # keep-sorted end
    ];
    shell.enableFishIntegration = true;
  };

  home = {
    shellAliases = {
      # keep-sorted start
      archive = "${getExe pkgs.p7zip} a -t7z -m0=lzma -mx=9 -mfb=64 -md=32m -ms=on $argv";
      cat = "${getExe pkgs.bat} -pp";
      df = getExe pkgs.duf;
      diff = getExe pkgs.bat-extras.batdiff;
      du = getExe pkgs.dust;
      man = getExe pkgs.bat-extras.batman;
      md = "mkdir";
      pb = getExe pkgs.bat-extras.prettybat;
      rd = "rmdir";
      rg = getExe pkgs.bat-extras.batgrep;
      # keep-sorted end
    };
    sessionVariables = {PAGER = "bat";};
  };

  programs = {
    fish = {
      enable = true;
      # fish
      interactiveShellInit = ''
        set fish_greeting
      '';

      # fish
      shellInit = ''
        eval (${lib.getExe pkgs.bat-extras.batpipe})
      '';

      shellAbbrs = {
        cpr = "cp -rf";
        rmr = "rm -rf";
        md = "mkdir -p";
        rd = "rmdir";

        lg = "lazygit";
        gp = "git push";
        gpf = "git push --force";
        gu = "git pull";
        gs = "git switch";
        gst = "git status -s";

        v = "nvim";
        q = "exit";
        c = "clear";

        "--help" = {
          position = "anywhere";
          regex = "^--help$";
          expansion = "--help 2>&1 | bat --style=plain --language=help";
        };

        "-h" = {
          position = "anywhere";
          regex = "^-h$";
          expansion = "-h 2>&1 | bat --style=plain --language=help";
        };
      };

      functions = {
        starship_transient_prompt_func = {
          body = "starship module character";
        };

        halp = {
          description = "Show command help with syntax highlighting";
          argumentNames = ["cmd"];
          # fish
          body = ''
            if test -z "$cmd"
              echo "Usage: halp <command>"
              return 1
            end
            $cmd --help 2>&1 | bat --style=plain --language=help
          '';
        };

        mkcd = {
          description = "Create directory and cd into it";
          argumentNames = ["dir"];
          # fish
          body = ''
            if test -z "$dir"
              echo "Usage: mkcd <directory>"
              return 1
            end
            mkdir -p -- "$dir" && cd -- "$dir"
          '';
        };

        fe = {
          description = "Find and edit file with fzf preview";
          # fish
          body = ''
            set -l file (${getExe pkgs.fd} --type f --hidden --follow --exclude .git | ${getExe pkgs.fzf} --preview '${getExe pkgs.bat} --color=always --style=numbers --line-range=:500 {}')
            if test -n "$file"
              $EDITOR -- "$file"
            end
          '';
        };

        fcd = {
          description = "Find directory and cd into it";
          # fish
          body = ''
            set -l dir (${getExe pkgs.fd} --type d --hidden --follow --exclude .git | ${getExe pkgs.fzf} --preview '${getExe pkgs.eza} --tree --level=1 --color=always -- {}')
            if test -n "$dir"
              cd -- "$dir"
            end
          '';
        };

        rg-fzf = {
          description = "Search with ripgrep and preview with fzf+bat";
          argumentNames = ["pattern"];
          # fish
          body = ''
            if test -z "$pattern"
              echo "Usage: rg-fzf <pattern>"
              return 1
            end
            ${getExe pkgs.ripgrep} --color=always --line-number --no-heading -- "$pattern" | \
              ${getExe pkgs.fzf} --ansi --delimiter : \
                --preview '${getExe pkgs.bat} --color=always --style=numbers --highlight-line {2} -- {1}' \
                --preview-window 'up,60%,+{2}-10'
          '';
        };
      };
    };

    starship = {
      enable = true;
      enableTransience = true;
      presets = ["pure-preset"];
      settings = {
        character = {
          success_symbol = "[λ](purple)";
          error_symbol = "[λ](red)";
          vimcmd_symbol = "[λ](green)";
        };
      };
    };

    # keep-sorted start block=yes newline_separated=yes
    bat = {
      enable = true;
      extraPackages = with pkgs.bat-extras; [batpipe batwatch];
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
      nix-direnv.enable = true;
    };

    eza = {
      enable = true;
      icons = "auto";
      git = true;
      extraOptions = ["--group-directories-first"];
    };

    fd = {
      enable = true;
      ignores = [".git/" "node_modules/" "dist/" "build/" "result/" ".next/" "__pycache__/" ".pytest_cache/" ".mypy_cache/" ".ruff_cache/" "*.pyc" ".venv/" "venv/" "*.swp" ".cache/" "*.cache"];
      extraOptions = ["--follow" "--hyperlink=auto"];
    };

    fzf.enable = true;

    ghostty.enable = true;

    ripgrep = {
      enable = true;
      arguments = ["--smart-case" "--hidden" "--glob=!.git/*" "-z"];
    };

    tealdeer = {
      enable = true;
      settings = {
        display = {
          use_pager = true;
          compact = true;
        };
        updates.auto_update = true;
      };
    };

    uv = {
      enable = true;
      settings = {exclude-newer = "3 days";};
    };

    vivid.enable = true;

    zoxide = {
      enable = true;
      options = ["--cmd cd"];
    };
    # keep-sorted end
  };
}
