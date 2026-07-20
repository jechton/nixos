{
  inputs,
  pkgs,
  ...
}: {
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
      };
      efi.canTouchEfiVariables = true;
    };
  };

  console.font = "${pkgs.terminus_font}/share/consolefonts/ter-d18n.psf.gz";
}
