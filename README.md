To install: `./install.sh --hostname [HOSTNAME] --age-key [FILE_PATH]`. Optionally include `--wifi-ssid [SSID] --wifi-pass [PASSWORD]`.

`install.sh` is a thin wrapper that sets `NIX_CONFIG` (experimental features, `accept-flake-config`) and re-execs itself via `sudo`, so nothing needs typing by hand at the live ISO shell first. It just runs `nix run .#install` under the hood — see `parts/install.nix` for the actual install logic.

## Inspiration
- [isabelroses](https://github.com/isabelroses/dotfiles)
- [phundrak](https://labs.phundrak.com/phundrak/nix-config)
