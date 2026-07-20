# the holy handbook to kernel parameters
# https://www.kernel.org/doc/html/latest/admin-guide/kernel-parameters.html
{
  boot.kernelParams = [
    # NixOS produces many wakeups per second, which is bad for battery life.
    # This kernel parameter disables the timer tick on the last 4 of 8 logical CPUs.
    "nohz_full=4-7"

    # make stack-based attacks on the kernel harder
    "randomize_kstack_offset=on"

    # vsyscalls have been considered unnecessary since 2016; disabling closes an ASLR bypass class
    "vsyscall=none"

    # reduce most of the exposure of a heap attack to a single cache
    "slab_nomerge"

    # disable debugfs, which exposes sensitive kernel data
    "debugfs=off"

    # disable sysrq keys; useful for debugging but also a local-attacker escape hatch
    "sysrq_always_enabled=0"

    # ignore atime updates except when they coincide with ctime/mtime changes
    "rootflags=noatime"

    # prevent the kernel from blanking plymouth out of the fb
    "fbcon=nodefer"

    # disable usb autosuspend
    "usbcore.autosuspend=-1"

    # disable resume-from-hibernate; matches security.protectKernelImage's nohibernate
    "noresume"

    # allow systemd to set and save the backlight state
    "acpi_backlight=native"

    # disable boot logo and cursor for a cleaner boot
    "logo.nologo"
    "vt.global_cursor_default=0"
  ];
}
