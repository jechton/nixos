To install: `./install.sh --hostname [HOSTNAME] --age-key [FILE_PATH]`. Optionally include `--wifi-ssid [SSID] --wifi-pass [PASSWORD]`.

`install.sh` re-execs itself via `sudo`, brings up networking (Ethernet or WiFi, using tools already on the live ISO), then sets `NIX_CONFIG` and runs `nix run .#install`, so nothing needs typing by hand at the live ISO shell first. `nix run` itself needs network to fetch the flake's inputs and substitutes, which is why WiFi setup happens in the bash wrapper rather than inside the flake. See `parts/install.nix` for the actual install logic (disko, impermanence snapshots, `nixos-install`).

## Building the install USB

This repo and your age key need to physically be on the machine before `install.sh` can do anything, so they ride along on the same stick as the NixOS ISO, in a second data partition carved out of the free space after the (small) ISO.

1. Find the stick's whole-disk device (not a partition): `lsblk`. Double check this, since the next step overwrites it. The rest of these steps assume `/dev/sdX`.

2. Flash the ISO:
   ```
   sudo umount /dev/sdX* 2>/dev/null
   sudo dd if=nixos-minimal-*.iso of=/dev/sdX bs=4M status=progress conv=fsync
   sync
   sudo partprobe /dev/sdX
   ```

3. Check the free space after the ISO's partition:
   ```
   sudo parted /dev/sdX print
   ```
   Note where the last partition ends (e.g. `1537MiB`), you'll need it next.

4. Add a data partition in that free space:
   ```
   sudo parted /dev/sdX -- mkpart primary ext4 1537MiB 100%
   sudo partprobe /dev/sdX
   ```

5. Format it and copy your files on (`N` is the new partition's number from step 4, e.g. `/dev/sdX2`):
   ```
   sudo mkfs.ext4 -L nixcfg /dev/sdXN
   sudo mount /dev/sdXN /mnt
   sudo cp -r /path/to/this/repo/. /mnt/
   sudo cp /path/to/age-key.txt /mnt/
   sudo umount /mnt
   ```

6. Boot the target off the stick (the ISO partition still boots fine). At the live shell:
   ```
   lsblk                      # find your new partition, e.g. /dev/sda2
   mkdir /mnt/cfg && mount /dev/sda2 /mnt/cfg
   cd /mnt/cfg
   ./install.sh --hostname <name> --age-key age-key.txt
   ```

## Inspiration
- [isabelroses](https://github.com/isabelroses/dotfiles)
- [phundrak](https://labs.phundrak.com/phundrak/nix-config)
