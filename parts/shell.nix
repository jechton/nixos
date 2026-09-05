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
        motd = "";

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
          pkgs.jq
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
            help = "Update flake inputs (all, named, or -p to pick interactively) and switch";
            command = ''
              if [ "''${1:-}" = "-p" ]; then
                shift
                inputs="$(nix flake metadata --json --flake "$PRJ_ROOT" | jq -r '.locks.nodes.root.inputs | keys[]' | sort)"
                picked="$(printf '%s\n' "$inputs" | fzf --multi --header 'tab to pick inputs to update, enter to confirm')"
                [ -n "$picked" ] || { echo "no inputs selected"; exit 0; }
                set -- $picked
              fi
              echo -e "Updating flake...\n"
              nix flake update --flake "$PRJ_ROOT" "$@"
              git -C "$PRJ_ROOT" add -A
              if [ "$#" -gt 0 ]; then
                git -C "$PRJ_ROOT" commit -m "chore: update $*"
              else
                git -C "$PRJ_ROOT" commit -m "chore: update inputs"
              fi
              nh os switch -d always
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
          {
            name = "secret";
            category = "tools";
            help = "Manage agenix secrets: secret <list|edit|show|rekey|wallpapers> [name|dir] (omit name on edit/show to pick interactively)";
            command = ''
              set +u
              cd "$PRJ_ROOT/secrets" || exit 1
              keyfile=/persist/age/key.txt
              action="''${1:-list}"
              name="''${2%.age}"
              file="$name.age"

              # The age identity is root-owned; stage it in a tmpfs scratch file
              # for one agenix call. $tmpkey stays empty for actions that skip it.
              tmpkey=""
              cleanup() { [ -n "$tmpkey" ] && rm -f "$tmpkey"; }
              trap cleanup EXIT
              stage_key() {
                tmpkey="$(mktemp -p "''${XDG_RUNTIME_DIR:-/tmp}")"
                sudo cat "$keyfile" > "$tmpkey"
              }
              pick_secret() {
                grep -oE '"[A-Za-z0-9_-]+\.age"' secrets.nix | tr -d '"' | sed 's/\.age$//' | sort -u \
                  | fzf --header "pick a secret to $1"
              }

              case "$action" in
                list)
                  declared="$(grep -oE '"[A-Za-z0-9_-]+\.age"' secrets.nix | tr -d '"' | sort -u)"
                  echo "declared in secrets.nix:"
                  for f in $declared; do
                    if [ -e "$f" ]; then
                      echo "  $f"
                    else
                      echo "  $f  (no file: run 'secret edit ''${f%.age}')"
                    fi
                  done
                  for f in *.age; do
                    [ -e "$f" ] || continue
                    case "$declared" in
                      *"$f"*) ;;
                      *) echo "  $f  (not declared in secrets.nix)" ;;
                    esac
                  done
                  ;;
                edit)
                  if [ -z "$name" ]; then
                    name="$(pick_secret edit)"
                    [ -n "$name" ] || { echo "no secret selected" >&2; exit 1; }
                    file="$name.age"
                  fi
                  if [ -s "$file" ]; then
                    stage_key
                    agenix -e "$file" -i "$tmpkey"
                  else
                    # A new secret only needs the recipient public keys.
                    agenix -e "$file"
                  fi
                  ;;
                show)
                  if [ -z "$name" ]; then
                    name="$(pick_secret show)"
                    [ -n "$name" ] || { echo "no secret selected" >&2; exit 1; }
                    file="$name.age"
                  fi
                  stage_key
                  agenix -d "$file" -i "$tmpkey"
                  ;;
                rekey)
                  stage_key
                  agenix -r -i "$tmpkey"
                  ;;
                wallpapers)
                  # Edit wallpapers.tar.age in place: decrypt to a scratch
                  # dir, open a shell there to add/remove images, re-pack on exit
                  # if anything changed. No persistent plaintext copy to drift.
                  work="$(mktemp -d -p "''${XDG_RUNTIME_DIR:-/tmp}")"
                  cleanup() { [ -n "$tmpkey" ] && rm -f "$tmpkey"; rm -rf "$work"; }
                  if [ -s wallpapers.tar.age ]; then
                    stage_key
                    agenix -d wallpapers.tar.age -i "$tmpkey" | tar -C "$work" -xf -
                  fi
                  digest() { ( cd "$work" && find . -type f -exec sha256sum {} + | sort | sha256sum ); }
                  before="$(digest)"
                  echo "extracted to $work — add/remove images, then exit the shell to re-pack"
                  ( cd "$work" && exec "$SHELL" )
                  if [ "$before" = "$(digest)" ]; then
                    echo "no changes, archive untouched"
                  else
                    archive="$(mktemp -p "''${XDG_RUNTIME_DIR:-/tmp}")"
                    tar -C "$work" -cf "$archive" .
                    [ -n "$tmpkey" ] || stage_key
                    EDITOR="cp $archive" agenix -e wallpapers.tar.age -i "$tmpkey"
                    rm -f "$archive"
                    echo "re-packed $(find "$work" -type f | wc -l) files"
                  fi
                  ;;
                *)
                  echo "usage: secret <list|edit|show|rekey|wallpapers> [name|dir]" >&2
                  exit 1
                  ;;
              esac
            '';
          }
        ];
      };
    };
}
