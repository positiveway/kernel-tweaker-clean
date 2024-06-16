# No Spaces are allowed between '=' and value

sysctl -w vm.swappiness=0
sysctl -w vm.page-cluster=0
sysctl -w vm.vfs_cache_pressure=50
sysctl -w vm.stat_interval=30
sysctl -w vm.compaction_proactiveness=0
sysctl -w vm.dirty_ratio=60
sysctl -w vm.page_lock_unfairness=4
sysctl -w vm.watermark_boost_factor=0

sysctl -w net.ipv4.tcp_low_latency=1
sysctl -w net.ipv4.tcp_timestamps=0
sysctl -w net.ipv4.tcp_slow_start_after_idle=0
sysctl -w net.ipv4.tcp_window_scaling=1
sysctl -w net.ipv4.tcp_congestion_control=bbr
sysctl -w net.ipv4.route.flush=1
sysctl -w net.core.rmem_default=31457280
sysctl -w net.core.rmem_max=33554432
sysctl -w net.core.wmem_default=31457280
sysctl -w net.core.wmem_max=33554432
sysctl -w net.core.somaxconn=65535
sysctl -w net.core.netdev_max_backlog=65536
sysctl -w net.core.optmem_max=25165824
sysctl -w net.ipv4.tcp_mem="786432 1048576 26777216"
sysctl -w net.ipv4.udp_mem="65536 131072 262144"
sysctl -w net.ipv4.tcp_rmem="8192 87380 33554432"
sysctl -w net.ipv4.udp_rmem_min=16384
sysctl -w net.ipv4.tcp_wmem="8192 65536 33554432"
sysctl -w net.ipv4.udp_wmem_min=16384

# Disable transparent huge pages
echo never > /sys/kernel/mm/transparent_hugepage/enabled
# Disable automatic NUMA memory balancing
echo 0 > /proc/sys/kernel/numa_balancing
# Disable kernel samepage merging
echo 0 > /sys/kernel/mm/ksm/run

# Maximizing I/O Throughput
# Minimal preemption granularity for CPU-bound tasks:
sysctl -w kernel.sched_min_granularity_ns=10000000
# This option delays the preemption effects of decoupled workloads
# and reduces their over-scheduling. Synchronous workloads will still
# have immediate wakeup/sleep latencies.
sysctl -w kernel.sched_wakeup_granularity_ns=15000000
# Sets the time before the kernel considers migrating a proccess to another core
sysctl -w kernel.sched_migration_cost_ns=5000000