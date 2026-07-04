{
  custom.storage = {
    enable = true;
    device = "/dev/vda";
  };

  boot = {
    initrd = {
      availableKernelModules = ["xhci_pci" "ohci_pci" "ehci_pci" "virtio_pci" "ahci" "usbhid" "sr_mod" "virtio_blk"];
      kernelModules = [];
    };
    kernelModules = ["kvm-amd"];
    extraModulePackages = [];
  };

  nixpkgs.hostPlatform = "x86_64-linux";
}
