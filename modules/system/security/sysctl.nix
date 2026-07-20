# find out what's recommended for you:
# > sudo sysctl -a > sysctl.txt
# > kernel-hardening-checker -l /proc/cmdline -c /proc/config.gz -s ./sysctl.txt
#
# https://docs.kernel.org/admin-guide/sysctl/vm.html
# https://sysctl-explorer.net/
{ config, ... }:
{
  boot.kernel.sysctl = {
    # the magic sysrq key allows low-level commands from the system console; disable it
    "kernel.sysrq" = 0;

    # restrict ptrace() to a pre-defined process relationship (e.g. parent/child)
    "kernel.yama.ptrace_scope" = 1;

    # hide kernel pointers even for processes with CAP_SYSLOG
    "kernel.kptr_restrict" = 2;

    # disable the bpf() JIT to eliminate spray attacks, unless the scx scheduler needs it
    "net.core.bpf_jit_enable" = config.services.scx.enable;

    # disable ftrace debugging
    "kernel.ftrace_enabled" = false;

    # avoid kernel memory address exposure via dmesg
    "kernel.dmesg_restrict" = 1;

    # disable SUID binary core dumps
    "fs.suid_dumpable" = 0;

    # disallow profiling at all levels without CAP_PERFMON/CAP_SYS_ADMIN
    "kernel.perf_event_paranoid" = 2;

    # require CAP_BPF to use bpf
    "kernel.unprivileged_bpf_disabled" = true;

    # prevent boot console log leaking information
    "kernel.printk" = "3 3 3 3";

    # restrict loading TTY line disciplines to CAP_SYS_MODULE, closing a local privesc path
    "dev.tty.ldisc_autoload" = 0;

    # kexec allows replacing the running kernel; redundant with security.protectKernelImage but explicit
    "kernel.kexec_load_disabled" = true;

    # disable TIOCSTI/TIOCLINUX ioctl, a known terminal-injection privesc vector
    "dev.tty.legacy_tiocsti" = 0;

    # mitigate some TOCTOU vulnerabilities around sticky world-writable dirs (e.g. /tmp)
    # https://www.kernel.org/doc/Documentation/admin-guide/sysctl/fs.rst
    "fs.protected_fifos" = 2;
    "fs.protected_hardlinks" = 1;
    "fs.protected_regular" = 2;
    "fs.protected_symlinks" = 1;

    # raise the memory mapping limit; some games and emulators need far more than the default
    "vm.max_map_count" = 2147483642;
  };
}
