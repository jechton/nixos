{ pkgs, ... }: {
  boot.initrd.systemd.storePaths = [
    pkgs.btrfs-progs
    pkgs.coreutils
    pkgs.util-linux
  ];

  boot.initrd.systemd.services.rollback = {
    description = "Rollback root and home btrfs subvolumes to blank snapshots";
    wantedBy = [ "initrd.target" ];
    after = [
      "cryptsetup.target"
      "dev-disk-by\\x2dlabel-nixos.device"
    ];
    requires = [ "dev-disk-by\\x2dlabel-nixos.device" ];
    before = [ "sysroot.mount" ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    path = [
      pkgs.btrfs-progs
      pkgs.coreutils
      pkgs.util-linux
    ];
    script = ''
      mkdir -p /mnt
      mount -t btrfs /dev/disk/by-label/nixos /mnt

      btrfs subvolume list -o /mnt/root \
        | cut -f9 -d' ' \
        | while read -r subvol; do
            btrfs subvolume delete "/mnt/$subvol"
          done

      btrfs subvolume delete /mnt/root
      btrfs subvolume snapshot /mnt/root-blank /mnt/root

      btrfs subvolume list -o /mnt/home \
        | cut -f9 -d' ' \
        | while read -r subvol; do
            btrfs subvolume delete "/mnt/$subvol"
          done

      btrfs subvolume delete /mnt/home
      btrfs subvolume snapshot /mnt/home-blank /mnt/home

      umount /mnt
    '';
  };

  environment.persistence."/persist" = {
    hideMounts = true;

    # No owning module for this
    files = [ "/etc/machine-id" ];
  };

  # /root is a read-only btrfs subvolume boundary in the blank snapshot.
  # Mount a tmpfs over it so root always has a writable home directory.
  fileSystems."/root" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "mode=0700"
      "size=256M"
    ];
    neededForBoot = true;
  };

  programs.fuse.userAllowOther = true;

  security.sudo.extraConfig = ''
    Defaults lecture = never
  '';
}
