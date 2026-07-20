{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.custom.storage;

  btrfsContent = {
    type = "btrfs";
    extraArgs = ["-L" "nixos" "-f"];
    subvolumes = {
      "/root" = {
        mountpoint = "/";
        mountOptions = ["subvol=root" "compress=zstd" "noatime"];
      };
      "/root-blank" = {};
      "/home" = {
        mountpoint = "/home";
        mountOptions = ["subvol=home" "compress=zstd" "noatime"];
      };
      "/home-blank" = {};
      "/nix" = {
        mountpoint = "/nix";
        mountOptions = ["subvol=nix" "compress=zstd" "noatime"];
      };
      "/persist" = {
        mountpoint = "/persist";
        mountOptions = ["subvol=persist" "compress=zstd" "noatime"];
      };
      "/log" = {
        mountpoint = "/var/log";
        mountOptions = ["subvol=log" "compress=zstd" "noatime"];
      };
      "/lib" = {
        mountpoint = "/var/lib";
        mountOptions = ["subvol=lib" "compress=zstd" "noatime"];
      };
      "/swap" = {
        mountpoint = "/persist/swap";
        mountOptions = ["subvol=swap" "noatime" "nodatacow" "compress=no"];
        swap.swapfile = {
          size = cfg.swapSize;
          priority = 0;
        };
      };
    };
  };
in {
  options.custom.storage = {
    enable = lib.mkEnableOption "Btrfs Impermanence storage layout";

    luks = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to encrypt the root partition with LUKS.";
    };

    device = lib.mkOption {
      type = lib.types.str;
      default = "/dev/nvme0n1";
      description = "The target block device for installation.";
    };

    swapSize = lib.mkOption {
      type = lib.types.str;
      default = "18G";
      description = "Size of the Btrfs swapfile (e.g., 18G, 34G).";
    };
  };

  config = lib.mkIf cfg.enable {
    disko.devices = {
      disk = {
        main = {
          type = "disk";
          inherit (cfg) device;
          content = {
            type = "gpt";
            partitions = {
              ESP = {
                label = "boot";
                name = "ESP";
                size = "1G";
                type = "EF00";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                  mountOptions = ["defaults" "umask=0077"];
                };
              };

              root = {
                size = "100%";
                label =
                  if cfg.luks
                  then "luks"
                  else "nixos";
                content =
                  if cfg.luks
                  then {
                    type = "luks";
                    name = "cryptroot";
                    content = btrfsContent;
                  }
                  else btrfsContent;
              };
            };
          };
        };
      };
    };

    fileSystems = {
      "/persist".neededForBoot = true;
      "/var/log".neededForBoot = true;
      "/var/lib".neededForBoot = true;
      "/home".neededForBoot = true;
    };

    boot = {
      initrd.luks.devices = lib.mkIf cfg.luks {
        cryptroot = {
          device = "/dev/disk/by-partlabel/luks";
          allowDiscards = true;
          preLVM = true;
        };
      };

      tmp = {
        useTmpfs = true;
        tmpfsSize = "25%";
      };
    };

    services = {
      btrfs.autoScrub = {
        enable = true;
        interval = "weekly";
        fileSystems = ["/"];
      };
      fstrim.enable = true;
    };

    zramSwap = {
      enable = true;
      algorithm = "zstd";
      priority = 5;
      memoryPercent = 50;
    };

    environment.systemPackages =
      [pkgs.btrfs-progs]
      ++ lib.optional cfg.luks pkgs.cryptsetup;
  };
}
