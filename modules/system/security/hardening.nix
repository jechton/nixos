{
  security = {
    protectKernelImage = true;
    lockKernelModules = false; # breaks docker, wireguard, and iptables

    # force-enable the Page Table Isolation (PTI) Linux kernel feature
    forcePageTableIsolation = true;

    # user namespaces are required for sandboxing (steam runtime, browser sandboxes)
    allowUserNamespaces = true;

    # add lockdown to nixpkgs' default LSM stack (landlock, yama, ..., bpf last)
    lsm = [ "lockdown" ];
  };
}
