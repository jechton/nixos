{ lib, config, ... }:
{
  # sched-ext userspace scheduler. scx_lavd is latency-aware, tuned for
  # interactive desktop and gaming workloads. sysctl.nix re-enables the bpf()
  # JIT when this is on, since scx schedulers run as BPF programs.
  config = lib.mkIf (!config.burrow.profiles.vm.enable) {
    services.scx = {
      enable = true;
      scheduler = "scx_lavd";
    };
  };
}
