To install: `./install.sh --hostname [HOSTNAME] --age-key [FILE_PATH]`. Optionally include `--wifi-ssid [SSID] --wifi-pass [PASSWORD]`.

`install.sh` re-execs itself via `sudo`, brings up networking (Ethernet or WiFi, using tools already on the live ISO), then sets `NIX_CONFIG` and runs `nix run .#install`, so nothing needs typing by hand at the live ISO shell first. `nix run` itself needs network to fetch the flake's inputs and substitutes, which is why WiFi setup happens in the bash wrapper rather than inside the flake. See `parts/install.nix` for the actual install logic (disko, impermanence snapshots, `nixos-install`).

## Inspiration
- [isabelroses](https://github.com/isabelroses/dotfiles)
- [phundrak](https://labs.phundrak.com/phundrak/nix-config)
