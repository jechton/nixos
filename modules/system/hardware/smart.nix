{ lib, ... }:
{
  services = {
    # monitor disk (NVMe) health via S.M.A.R.T.
    smartd.enable = true;

    # not using lvm; btrfs + luks handles storage here
    lvm.enable = lib.mkDefault false;
  };
}
