# OOM prevention and handling on a NixOS laptop

Setup: 14 GB RAM, zram (zstd, 100% of RAM, prio 5), 8 GB btrfs swapfile (prio 0), earlyoom (mem 8/4, swap 10/5), nix `max-jobs = 2`, `cores = 4`, `build-dir = /var/tmp`.
Claims without a primary source are marked **unverified**. Values marked "judgment" are my tuning choices, not documented numbers.

## Recommendation table

| Setting | Suggested value | Source |
|---|---|---|
| `zramSwap.memoryPercent` | keep 100 (50 to 100 all sane) | https://docs.kernel.org/admin-guide/blockdev/zram.html |
| zram priority vs swapfile | zram 5, swapfile 0 (as is) | https://raw.githubusercontent.com/NixOS/nixpkgs/master/nixos/modules/config/zram.nix |
| `vm.swappiness` | 150 (judgment, range 100 to 180) | https://docs.kernel.org/admin-guide/sysctl/vm.html |
| `vm.page-cluster` | 0 (judgment; rationale unverified) | https://docs.kernel.org/admin-guide/sysctl/vm.html |
| earlyoom kill rule | needs mem AND swap both low; raise swap kill threshold | https://github.com/rfjakob/earlyoom/blob/master/main.c |
| earlyoom `-p` | add | https://github.com/rfjakob/earlyoom/blob/master/README.md |
| systemd-oomd | leave idle (NixOS default) or use for user slices only | https://www.freedesktop.org/software/systemd/man/latest/systemd-oomd.service.html |
| nix eval memory cap | `systemd-run --user --scope -p MemoryHigh=.. -p MemoryMax=..` | https://www.freedesktop.org/software/systemd/man/latest/systemd.resource-control.html |
| nix-daemon memory cap | `systemd.services.nix-daemon.serviceConfig.MemoryHigh/MemoryMax` | same as above |
| swapfile | NOCOW, no compression, single device, own subvolume (already so) | https://btrfs.readthedocs.io/en/latest/Swapfile.html |

## 1. zram sizing and swap priority

- zram `disksize` is the uncompressed capacity. The kernel doc says "There is little point creating a zram of greater than twice the size of memory since we expect a 2:1 compression ratio", and that an idle zram costs about 0.1% of its size. So 100% is inside the documented sane range. https://docs.kernel.org/admin-guide/blockdev/zram.html
- NixOS `memoryPercent` is "the maximum total memory that can be stored in the zram swap devices, as a percentage of total RAM" (default 50). It does not reserve memory. https://raw.githubusercontent.com/NixOS/nixpkgs/master/nixos/modules/config/zram.nix
- Caveat: at a 2:1 ratio, a full 14 GB zram holds about 7 GB of compressed pages, i.e. half of RAM. Once zram is full, working set plus zram compete for the same 14 GB. Treat zram as a buffer, not extra capacity. At 100% the system can reach "swap nearly full" with little MemAvailable left; the 2:1 ratio is the kernel doc's expectation, the actual ratio on this machine is unmeasured (`zramctl` shows it).
- Priority: the NixOS option says priority "should be higher than that of any disk-based swap, so zram fills before the system falls back to disk". Current 5 vs 0 satisfies this. Same source as above. (Kernel swap(5) semantics page could not be fetched: unverified from man7, but the NixOS description states the behavior.)
- The kernel's `mem_limit` on zram caps the RAM zram may use for compressed data (0 disables). The NixOS option `memoryMax` is the equivalent cap. Setting it bounds how much RAM zram can consume. https://docs.kernel.org/admin-guide/blockdev/zram.html

## 2. swappiness and page-cluster

- Kernel doc: swappiness is "the rough relative IO cost of swapping and filesystem paging" on a 0 to 200 scale, default 60, 100 means equal cost. Values above 100 "can be considered" for in-memory swap such as zram or zswap. Worked example: swap IO twice as fast as filesystem IO gives about 133. https://docs.kernel.org/admin-guide/sysctl/vm.html
- The doc gives no exact number for zram. 150 is a judgment value; the doc says the best value needs experimentation.
- `vm.page-cluster`: default 3 (8 pages), log scale, 0 means one page, i.e. no swap readahead. https://docs.kernel.org/admin-guide/sysctl/vm.html
- Why 0 suits zram (no seek cost, readahead wastes decompression): not stated in the kernel doc. **Unverified from a primary source.**
- The NixOS zram module sets neither sysctl (it only emits size, algorithm, priority, writeback). https://raw.githubusercontent.com/NixOS/nixpkgs/master/nixos/modules/config/zram.nix
- Note: a high swappiness also pushes pages to the disk swapfile once zram is full; it does not distinguish devices. **Unverified**, inferred from the doc's single-scale description.

## 3. earlyoom vs systemd-oomd

How earlyoom's thresholds combine (confirmed in source):
- `lowmem_sig()` kills only when both conditions hold: `MemAvailablePercent <= mem_kill_percent && SwapFreePercent <= swap_kill_percent` (SIGKILL), else the same test with the term percents (SIGTERM). Otherwise nothing happens. https://github.com/rfjakob/earlyoom/blob/master/main.c
- README: "both memory and swap must be below minimum for earlyoom to act". https://github.com/rfjakob/earlyoom/blob/master/README.md
- `-m PERCENT[,KILL_PERCENT]`: SIGTERM below PERCENT, SIGKILL below KILL_PERCENT (default half). Same for `-s`. The NixOS module passes the kill threshold as the second `-m`/`-s` value. https://raw.githubusercontent.com/NixOS/nixpkgs/master/nixos/modules/services/system/earlyoom.nix
- Defaults are 10/5 for both. https://github.com/rfjakob/earlyoom/blob/master/main.c

Implication for the observed kill: swap at ~95% full is exactly the swap kill line (5% free of the combined 14 GB zram + 8 GB file, about 1.1 GB). earlyoom also needed MemAvailable under 4% (about 0.56 GB). A fast-allocating nix eval can go from "above 4%" to a kernel OOM between polls, so earlyoom never saw both conditions at once. This is an inference from the thresholds; the poll timing was not measured. **Unverified.** Raising the kill thresholds (more headroom) is the only lever that fires earlier, since the AND rule cannot be relaxed except by raising either side.

earlyoom also supports `-p` ("set niceness of earlyoom to -20 and oom_score_adj to -100") so it keeps running under pressure. https://github.com/rfjakob/earlyoom/blob/master/README.md

systemd-oomd:
- Uses cgroups v2 and PSI, acts only on units with `ManagedOOMSwap=kill` or `ManagedOOMMemoryPressure=kill`, SIGKILLs a whole candidate cgroup. https://www.freedesktop.org/software/systemd/man/latest/systemd-oomd.service.html
- The man page suggests the default 60% pressure limit for `system.slice` and a lower value such as 40% for `user@$UID.service`. Same page.
- NixOS enables `systemd.oomd` by default, but it only monitors root/system/user slices if `enableRootSlice`, `enableSystemSlice` or `enableUserSlices` is set (pressure limit default 80%). So today it is running and idle. https://raw.githubusercontent.com/NixOS/nixpkgs/master/nixos/modules/system/boot/systemd/oomd.nix
- Neither earlyoom's README nor the systemd man page says whether running both is supported or advised. **Unverified.** Practical choice: keep earlyoom (it has the `--avoid/--prefer` regexes the repo relies on) and either leave oomd idle or enable only `enableUserSlices`. Do not enable both on the same slice without testing, since two killers may act on the same pressure event (inference).

## 4. Nix: jobs, cores, eval memory

- `max-jobs`: "Maximum number of jobs that Nix tries to build locally in parallel", default 1, `auto` is CPU count. `cores`: default 0 means detected core count, passed as `NIX_BUILD_CORES`. https://nix.dev/manual/nix/latest/command-ref/conf-file.html
- Peak build threads are about `max-jobs * cores` (inference: 2 x 4 = 8 threads). Memory-heavy builds (LTO, Rust, Chromium) scale with jobs, not cores; lowering `max-jobs` is the stronger lever. The manual does not state per-job memory. **Unverified** as a rule.
- Eval memory: the manual documents no setting that limits eval memory (`eval-cache` only toggles the flake eval cache; `max-call-depth` limits depth). https://nix.dev/manual/nix/latest/command-ref/conf-file.html
- `eval-cores`: not in the conf-file reference or the `nix eval` page I fetched. **Unverified**; do not rely on it for memory (more eval threads would raise, not lower, memory).
- `GC_INITIAL_HEAP_SIZE`: "If Nix has been configured to use the Boehm garbage collector, this variable sets the initial size of the heap in bytes." (default 384 MiB). It affects start-up heap and GC frequency, not a hard cap. https://nix.dev/manual/nix/latest/command-ref/env-common.html
- Hard cap for an eval: run the client under a transient scope, `systemd-run --user --scope -p MemoryHigh=8G -p MemoryMax=10G -p MemorySwapMax=2G nix build ...`. `systemd-run --scope` and `-p NAME=VALUE` are documented (the doc example uses IOWeight; the MemoryMax form is my application of the same mechanism). https://www.freedesktop.org/software/systemd/man/latest/systemd-run.html
- Builds run under the daemon. The NixOS nix-daemon module has only CPU and IO scheduling options (`daemonCPUSchedPolicy`, `daemonIOSchedClass`, `daemonIOSchedPriority`) and no memory option, so use `systemd.services.nix-daemon.serviceConfig`. https://raw.githubusercontent.com/NixOS/nixpkgs/master/nixos/modules/services/system/nix-daemon.nix
- Whether a `nix` CLI eval runs in the client (user cgroup) or the daemon depends on the command; for flake builds the evaluator is in the client. **Unverified** from the Nix manual.

## 5. cgroup limits via systemd

- `MemoryHigh=` throttles: usage can exceed it, processes are "heavily slowed down" and memory is reclaimed aggressively. `MemoryMax=` is absolute; if usage cannot be reduced the OOM killer runs inside the unit. The man page recommends `MemoryHigh=` as the main control and `MemoryMax=` as a backstop. https://www.freedesktop.org/software/systemd/man/latest/systemd.resource-control.html
- Kernel: going over `memory.high` "never invokes the OOM killer and under extreme conditions the limit may be breached". `memory.max` invokes the OOM killer in the cgroup. `memory.swap.max` stops anonymous memory from being swapped out. https://docs.kernel.org/admin-guide/cgroup-v2.html
- `MemorySwapMax=` percentages are relative to total swap size. https://www.freedesktop.org/software/systemd/man/latest/systemd.resource-control.html
- `MemoryLow=` protects a unit from reclaim (useful for the compositor); it is weaker than `MemoryMin=`. Same page.
- Slice-level limits on NixOS: `systemd.slices.<name>.sliceConfig` or `systemd.services.<name>.serviceConfig`, and for per-user `systemd.user.slices`. A limit on the whole `user.slice` would also throttle the desktop, so prefer limiting the nix-daemon service and ad hoc `systemd-run` scopes (judgment).

## 6. Swapfile on btrfs

- Requirements: kernel 5.0+, single device, single data profile, fully preallocated, NOCOW (which implies no checksums and no compression). `btrfs filesystem mkswapfile` needs btrfs-progs 6.1+. https://btrfs.readthedocs.io/en/latest/Swapfile.html
- Snapshots: a subvolume holding an active swapfile cannot be snapshotted. Keep the swapfile in its own subvolume (already `subvol=swap`). Same page.
- Hazards: with an active swapfile, balance and scrub skip its block groups (data left unbalanced/unverified), "especially discouraged for the root filesystem". Same page.
- Priority: 0 against zram 5 is correct; disk swap is then used only after zram fills (see section 1). Heavy use of the disk swap means the system is already thrashing; it is a safety net, not capacity.
- Whether disko's `swap.swapfile` creates the file via `mkswapfile` or equivalent NOCOW steps: **unverified**, check with `lsattr /persist/swap/swapfile` (expect `C`) and `swapon --show`.

## What to change in this repo

`modules/system/hardware/disk.nix`
- Keep `zramSwap.memoryPercent = 100` and `priority = 5`. Optionally add `memoryMax` (bytes) if zram eating half of RAM hurts; measure first with `zramctl`.
- Add next to `zramSwap`: `boot.kernel.sysctl."vm.swappiness" = 150;` and `boot.kernel.sysctl."vm.page-cluster" = 0;` (judgment values).
- Swapfile mount options (`nodatacow`, `compress=no`, own subvol, priority 0) already match the btrfs doc. Check `cfg.swapSize` in the host files: the module default is 18G, the observed swapfile is 8G.

`modules/system/hardware/earlyoom.nix`
- Raise the swap side so both conditions are met earlier: for example `freeSwapThreshold = 20; freeSwapKillThreshold = 10;` and `freeMemThreshold = 10; freeMemKillThreshold = 5;` (judgment; the AND rule means both must be at or below).
- Add `"-p"` to `extraArgs` so earlyoom keeps scheduling under pressure.
- Leave `--avoid/--prefer` as is. Consider `ghostty`/`fish` already avoided; `nix` is in `prefer`, which matches the observed victim class.

`modules/system/nixos.nix`
- Keep `max-jobs = 2`, `cores = 4`. If builds still push memory, lower `max-jobs` to 1 before lowering `cores`.
- Add a cgroup cap on the daemon: `systemd.services.nix-daemon.serviceConfig = { MemoryHigh = "10G"; MemoryMax = "12G"; };` (judgment values for 14 GB RAM), so a runaway build is killed in its cgroup before the kernel picks a victim system-wide.
- For big evals, document or alias `systemd-run --user --scope -p MemoryHigh=8G -p MemoryMax=10G nix ...` (the devshell `check` and `sw` commands are candidates). Do not set `GC_INITIAL_HEAP_SIZE` as an OOM fix; it is not a cap.
