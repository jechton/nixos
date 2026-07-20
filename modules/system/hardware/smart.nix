{ lib, config, ... }:
{
  services = {
    # monitor disk (NVMe) health via S.M.A.R.T.; meaningless on virtio-blk/scsi
    smartd.enable = !config.burrow.profiles.vm.enable;

    # not using lvm; btrfs + luks handles storage here
    lvm.enable = lib.mkDefault false;
  };
}
