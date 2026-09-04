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
            help = "Update flake inputs (all, or just those named) and switch";
            command = ''
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
            help = "Manage agenix secrets: secret <list|edit|show|rekey|wallpapers> [name|dir]";
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
                  [ -n "$name" ] || { echo "usage: secret edit <name>" >&2; exit 1; }
                  if [ -s "$file" ]; then
                    stage_key
                    agenix -e "$file" -i "$tmpkey"
                  else
                    # A new secret only needs the recipient public keys.
                    agenix -e "$file"
                  fi
                  ;;
                show)
                  [ -n "$name" ] || { echo "usage: secret show <name>" >&2; exit 1; }
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
