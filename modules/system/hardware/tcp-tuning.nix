{
  boot.kernel.sysctl = {
    # TCP hardening
    # prevent bogus ICMP errors from filling up logs
    "net.ipv4.icmp_ignore_bogus_error_responses" = 1;

    # reverse path filtering does source validation of packets received on all
    # interfaces, mitigating some IP spoofing
    "net.ipv4.conf.default.rp_filter" = 1;
    "net.ipv4.conf.all.rp_filter" = 1;

    # don't accept IP source route packets (we're not a router)
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv6.conf.all.accept_source_route" = 0;

    # don't send ICMP redirects (we're not a router)
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;

    # refuse ICMP redirects (MITM mitigation)
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.secure_redirects" = 0;
    "net.ipv4.conf.default.secure_redirects" = 0;
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.default.accept_redirects" = 0;

    # protect against SYN flood attacks
    "net.ipv4.tcp_syncookies" = 1;

    # incomplete protection against TIME-WAIT assassination
    "net.ipv4.tcp_rfc1337" = 1;

    "net.ipv4.conf.all.log_martians" = true;
    "net.ipv4.conf.default.log_martians" = true;
    "net.ipv4.icmp_echo_ignore_broadcasts" = true;

    # minor fingerprinting/privacy improvement
    "net.ipv4.tcp_timestamps" = 0;

    # TCP optimization
    # TCP Fast Open packs data into the initial SYN, reducing latency; 3 = enable for both directions
    "net.ipv4.tcp_fastopen" = 3;

    # bufferbloat mitigation + slight throughput/latency improvement
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.core.default_qdisc" = "cake";

    "net.core.somaxconn" = 8192;
    "net.ipv4.ip_local_port_range" = "16384 65535";
    "net.ipv4.tcp_mtu_probing" = 1;
    "net.ipv4.tcp_slow_start_after_idle" = 0;
    "net.netfilter.nf_conntrack_generic_timeout" = 60;
    "net.netfilter.nf_conntrack_max" = 1048576;
    "net.netfilter.nf_conntrack_tcp_timeout_established" = 600;
    "net.netfilter.nf_conntrack_tcp_timeout_time_wait" = 1;

    # buffer limits: 32M max, 16M default
    "net.core.rmem_max" = 33554432;
    "net.core.wmem_max" = 33554432;
    "net.core.rmem_default" = 16777216;
    "net.core.wmem_default" = 16777216;
    "net.core.optmem_max" = 40960;

    # https://blog.cloudflare.com/the-story-of-one-latency-spike/
    "net.ipv4.tcp_mem" = "786432 1048576 26777216";
    "net.ipv4.tcp_rmem" = "4096 1048576 2097152";
    "net.ipv4.tcp_wmem" = "4096 65536 16777216";

    # https://nateware.com/2013/04/06/linux-network-tuning-for-2013/
    "net.core.netdev_max_backlog" = 100000;
    "net.core.netdev_budget" = 100000;
    "net.core.netdev_budget_usecs" = 100000;
    "net.ipv4.tcp_max_syn_backlog" = 30000;
    "net.ipv4.tcp_max_tw_buckets" = 2000000;
    "net.ipv4.tcp_tw_reuse" = 1;
    "net.ipv4.tcp_fin_timeout" = 10;
    "net.ipv4.udp_rmem_min" = 8192;
    "net.ipv4.udp_wmem_min" = 8192;
  };
}
