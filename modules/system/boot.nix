{
  inputs,
  config,
  pkgs,
  ...
}:
{
  nixpkgs.overlays = [
    inputs.nix-cachyos-kernel.overlays.pinned
  ];

  boot = {
    kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-bore;

    initrd.systemd.enable = true;
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
        editor = false;
        # "max" queries the highest-resolution UEFI GOP text mode; on QEMU's
        # virtio-gpu + OVMF that query often renders blank even though the
        # menu is still running and accepting input. "keep" just uses
        # whatever mode firmware already set, which is reliable there.
        consoleMode = if config.burrow.profiles.vm.enable then "keep" else "max";
        bootCounting.enable = true;
      };
      generationsDir.copyKernels = true;
      efi.canTouchEfiVariables = true;
    };
  };

  console.font = "${pkgs.terminus_font}/share/consolefonts/ter-d18n.psf.gz";
}
