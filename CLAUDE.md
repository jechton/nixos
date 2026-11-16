Personal NixOS flake (flake-parts) for two hosts: `floptop` (laptop) and `vm`. Uses home-manager, disko, impermanence, agenix, niri, and stylix.

## Commands

Run from the devshell (`use flake` via direnv, or `nix develop`). Type `menu` to list them.

- `check`: format, then `nix flake check --no-build`. Run after any change.
- `os-test`: test a system config without making it the boot default.
- `sw`: build and switch to a system config.
- `update [inputs...]`: update flake inputs (`-p` to pick), commit the lockfile, switch.
- `check-updates`: list inputs with newer revisions. Does not touch `flake.lock`.
- `plugin-test`: dry-test with the local noctalia-plugins checkout (no commit or lock change).
- `gc`: garbage collect and optimise the store.
- `hash-url <url>`: print the SRI sha256 of a URL.
- `secret <list|edit|show|rekey|wallpapers> [name]`: manage agenix secrets.
- `nix fmt`: run treefmt (nixfmt, statix, deadnix, keep-sorted, typos).

No test suite. Correct means it evaluates and builds.

Pre-commit hooks run `treefmt --fail-on-change` and `betterleaks` (secret scan). Never use `--no-verify`.

## Architecture

- **Entry point:** `flake.nix` defines `mkHost`. Each host is `mkHost { hostModule = ./hosts/<name>; }`. Files under `modules/system/` and `modules/home/` are imported automatically by `import-tree`. Adding a file is enough, there is no module list to edit.
- **Options:** custom options live under `burrow.*`. A module both declares (`options.burrow.x`) and implements (`config = lib.mkIf cfg.enable { ... }`) its option. Grep `options.burrow` before assuming an option exists.
- **Hosts:** `hosts/<name>/default.nix` is thin: hostname, facter report, `burrow.*` toggles, `system.stateVersion`. Behavior lives in `modules/system/**`, behind flags.
- **Profiles:** `burrow.profiles.laptop` / `.vm` are declared in `modules/system/profiles.nix` and read back in home scope by `modules/home/profiles.nix` via `osConfig`. Use this pattern for any option both sides need.
- **Home-manager:** `modules/system/users.nix` creates the user and imports `home/<username>/default.nix`, which imports `modules/home/**`.
- **Secrets:** agenix, `secrets/*.age`, keyed by `secrets/agenix-rules.nix`. Use `config.age.secrets.<name>.path`. To add one: add an entry to the rules file, then `secret edit <name>`. Needs `burrow.agenix.enable = true`.
- **Install:** `install.sh` runs on the live ISO, sets up networking, then runs `nix run .#install` (`parts/install.nix`: disko, impermanence, `nixos-install`). Networking stays out of the flake because `nix run` needs it first.
- **Impermanence:** root is wiped on boot. Each module persists its own state (grep `persistence`). Shared pieces are in `modules/system/impermanence.nix` and `home/jeremiah/impermanence.nix`. When you add a service that keeps state, persist its paths in the same module.
- **Research notes:** `docs/research/` holds saved findings. Check there before researching again.

## Conventions

- No AI-isms: no filler, no hedging. No em dashes, use a comma, colon, or period. Applies to code, comments, commits, and docs.
- Comments say what the code is and why, not how it changed. No "now does X" or "changed to Y".
- Simple, readable code over clever one-liners. DRY.
- Sorted lists sit between keep-sorted markers. Add entries inside them, alphabetically.
- Stylix colors: `config.lib.stylix.colors.withHashtag.baseXX` (already has `#`).
- Do not hand-format Nix. Run `nix fmt`.
- Noctalia changes: write Luau plugins (own plugins in `~/Projects/noctalia-plugins`). Do not patch noctalia source with `overrideAttrs`.
- Do not commit unless asked.
