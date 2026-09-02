A personal NixOS flake config (flake-parts based) for two hosts: `floptop` (laptop) and `vm`. Uses home-manager, disko, impermanence, agenix, niri (Wayland compositor), and stylix for theming.

## Commands

Run from inside the devshell (`use flake` via direnv, or `nix develop`). Type `menu` in the devshell to list these.

- `check`: `nix fmt "$PRJ_ROOT" && nix flake check --no-build "$PRJ_ROOT"`. Run this after any change.
- `os-test`: `nh os test -d always "$@"`, dry-test a system config without making it the boot default.
- `sw`: `nh os switch -d always "$@"`, build and switch to a system config.
- `update [inputs...]`: `nix flake update` (all inputs, or only the named ones) then commits the lockfile and switches.
- `gc`: `nh clean all -k 4 --optimise "$@"`.
- `hash-url <url>`: prefetch a URL and print its SRI sha256.
- `nix fmt` alone runs the treefmt suite (nixfmt, statix, deadnix, keep-sorted, typos).

There is no test suite beyond `nix flake check`; correctness is "does it evaluate and build."

Pre-commit hooks (git-hooks.nix, installed by the devshell) run `treefmt --fail-on-change` and `betterleaks` (secret scanning) on every commit. Don't bypass with `--no-verify`.

## Architecture

**Entry point:** `flake.nix` defines `mkHost` and builds `nixosConfigurations.floptop` / `.vm`. Each host is `mkHost { hostModule = ./hosts/<name>; }`. System modules are pulled in automatically via `import-tree ./modules/system`; there is no manual module list to edit when adding a file there. Dropping a `.nix` file under `modules/system/` (or `modules/home/`) is enough for it to be imported.

**Custom options live under the `burrow.*` namespace**, e.g. `burrow.users`, `burrow.storage`, `burrow.profiles`, `burrow.theme`, `burrow.agenix`. Each module both *declares* (`options.burrow.x`) and *implements* (`config = lib.mkIf cfg.enable { ... }`) its own option. Grep for `options.burrow` to find where a given knob is defined before assuming it exists.

**Host files** (`hosts/floptop/default.nix`, `hosts/vm/default.nix`) are thin: hostname, hardware facter report path, `burrow.storage`/`burrow.agenix`/`burrow.profiles` toggles, and `system.stateVersion`. All actual behavior lives in `modules/system/**`, gated behind profile/feature flags so hosts opt in rather than hardcoding.

**Profiles** (`burrow.profiles.laptop` / `.vm`) are declared once in `modules/system/profiles.nix` and mirrored into home-manager scope via `modules/home/profiles.nix`, which reads them back off `osConfig`. This is the pattern for any option that both system and home modules need to see: declare it system-side, re-expose it home-side by reading `osConfig`.

**Home-manager wiring:** `modules/system/users.nix` is what actually turns on the primary user. It sets up the Linux user account *and* imports `home/<username>/default.nix` into `home-manager.users.<username>`, passing `username`/`displayName`/`gitEmail` as `_module.args`. `home/jeremiah/default.nix` in turn imports all of `modules/home/**` via `import-tree`. So home-manager modules are auto-discovered the same way system modules are.

**Secrets** are agenix-encrypted (`secrets/*.age`), keyed off the age public key in `secrets/secrets.nix`. Reference a secret in a module as `config.age.secrets.<name>.path`. To add one: add an entry to `secrets/secrets.nix`, then `secret edit <name>` in the devshell (`secret list` / `secret show <name>` / `secret rekey` also exist; the wrapper pulls the root-owned age key via sudo). Requires `burrow.agenix.enable = true` on the host.

**Install flow:** `install.sh` is a standalone bash script (no flake dependency) meant to run from the NixOS live ISO. It re-execs as root, brings up networking with tools already on the ISO, then hands off to `nix run .#install`, which is `parts/install.nix` (disko partitioning, impermanence snapshot setup, `nixos-install`). Networking setup is deliberately kept out of the flake since `nix run` itself needs network already.

**Impermanence:** root is wiped on boot; persistent state is opted into explicitly per-host/module (see `modules/system/impermanence.nix` and `home/jeremiah/impermanence.nix`) rather than persisted by default.

## Conventions

- No AI-isms: no filler, no hedging, no "as an AI". No em dashes, use a comma, colon, or period instead. Applies to code, comments, commit messages, and docs.
- Comments describe the code as it stands now (what it does, why it's there), not the history of changes made to reach it. Don't write comments like "now does X" or "changed to Y", write what X or Y is.
- Prefer simple, readable code over clever or terse one-liners. DRY.
- Sorted lists in Nix files are bounded by keep-sorted marker comments (see any module for the exact syntax; enforced by treefmt's keep-sorted formatter): keep entries alphabetical within those blocks and add new entries inside them, not appended after.
- Colors in stylix-themed modules: use `config.lib.stylix.colors.withHashtag.baseXX` (already includes the `#` prefix).
- Formatting/linting is entirely delegated to `nix fmt` (treefmt), don't hand-format Nix files.
