#!/system/bin/sh
# YAKT v107
# Author: @NotZeetaa (Github)
# ×××××××××××××××××××××××××× #

sleep 30

# Function to append a message to the specified log file
log_message() {
    local log_file="$1"
    local message="$2"
    echo "[$(date "+%H:%M:%S")] $message" >> "$log_file"
}

# Function to log info messages
log_info() {
    log_message "$INFO_LOG" "$1"
}

# Function to log error messages
log_error() {
    log_message "$ERROR_LOG" "$1"
}

# Useful for debugging ig ¯\_(ツ)_/¯
# shellcheck disable=SC3033
# log_debug() {
#     log_message "$DEBUG_LOG" "$1"
# }

# Function to write a value to a specified file
write_value() {
    local file_path="$1"
    local value="$2"

    # Check if the file exists
    if [ ! -f "$file_path" ]; then
        log_error "Error: File $file_path does not exist."
        return 1
    fi

    # Make the file writable
    chmod +w "$file_path" 2>/dev/null

    # Write new value, log error if it fails
    if ! echo "$value" >"$file_path" 2>/dev/null; then
        log_error "Error: Failed to write to $file_path."
        return 1
    else
        return 0
    fi
}

NETWORK_TWEAK_PERFORMANCE=true
NETWORK_TWEAK_EXTRA=false
NETWORK_TWEAK_MEMORY=false
MEMORY_TWEAK_LATENCY=false

MODDIR=${0%/*} # Get parent directory

# Modify the filenames for logs
INFO_LOG="${MODDIR}/info.log"
ERROR_LOG="${MODDIR}/error.log"
# DEBUG_LOG="${MODDIR}/debug.log"

# Prepare log files
:> "$INFO_LOG"
:> "$ERROR_LOG"
# :> "$DEBUG_LOG"

# Variables
UCLAMP_PATH="/dev/stune/top-app/uclamp.max"
CPUSET_PATH="/dev/cpuset"
MODULE_PATH="/sys/module"
KERNEL_PATH="/proc/sys/kernel"
IPV4_PATH="/proc/sys/net/ipv4"
NET_CORE_PATH="/proc/sys/net/core"
MEMORY_PATH="/proc/sys/vm"
MGLRU_PATH="/sys/kernel/mm/lru_gen"
SCHEDUTIL2_PATH="/sys/devices/system/cpu/cpufreq/schedutil"
SCHEDUTIL_PATH="/sys/devices/system/cpu/cpu0/cpufreq/schedutil"
ANDROID_VERSION=$(getprop ro.build.version.release)
TOTAL_RAM=$(free -m | awk '/Mem/{print $2}')

# Log starting information
log_info "Starting YAKT v107"
log_info "Build Date: 06/06/2024"
log_info "Author: @NotZeetaa (Github)"
log_info "Device: $(getprop ro.product.system.model)"
log_info "Brand: $(getprop ro.product.system.brand)"
log_info "Kernel: $(uname -r)"
log_info "ROM Build Type: $(getprop ro.system.build.type)"
log_info "Android Version: $ANDROID_VERSION"

# Schedutil rate-limits tweak
log_info "Applying schedutil rate-limits tweak"
if [ -d "$SCHEDUTIL2_PATH" ]; then
    write_value "$SCHEDUTIL2_PATH/up_rate_limit_us" 10000
    write_value "$SCHEDUTIL2_PATH/down_rate_limit_us" 20000
    log_info "Applied schedutil rate-limits tweak"
elif [ -e "$SCHEDUTIL_PATH" ]; then
    for cpu in /sys/devices/system/cpu/*/cpufreq/schedutil; do
        write_value "${cpu}/up_rate_limit_us" 10000
        write_value "${cpu}/down_rate_limit_us" 20000
    done
    log_info "Applied schedutil rate-limits tweak"
else
    log_info "Abort: Not using schedutil governor"
fi

# Grouping tasks tweak
log_info "Disabling Sched Auto Group..."
write_value "$KERNEL_PATH/sched_autogroup_enabled" 0
log_info "Done."

# Enable CRF by default
log_info "Enabling child_runs_first"
write_value "$KERNEL_PATH/sched_child_runs_first" 1
log_info "Done."

# Set kernel.perf_cpu_time_max_percent to 10
log_info "Setting perf_cpu_time_max_percent to 10"
write_value "$KERNEL_PATH/perf_cpu_time_max_percent" 10
log_info "Done."

# Disable certain scheduler logs/stats
# Also iostats & reduce latency
# Credits to tytydraco
log_info "Disabling some scheduler logs/stats"
if [ -e "$KERNEL_PATH/sched_schedstats" ]; then
    write_value "$KERNEL_PATH/sched_schedstats" 0
fi
write_value "$KERNEL_PATH/printk" "0        0 0 0"
write_value "$KERNEL_PATH/printk_devkmsg" "off"
for queue in /sys/block/*/queue; do
    write_value "$queue/iostats" 0
    write_value "$queue/nr_requests" 64
done
log_info "Done."

# Disable Timer migration
log_info "Disabling Timer Migration"
write_value "$KERNEL_PATH/timer_migration" 0
log_info "Done."

# Cgroup tweak for UCLAMP scheduler
if [ -e "$UCLAMP_PATH" ]; then
    # Uclamp tweaks
    # Credits to @darkhz
    log_info "UCLAMP scheduler detected, applying tweaks..."
    top_app="${CPUSET_PATH}/top-app"
    write_value "$top_app/uclamp.max" max
    write_value "$top_app/uclamp.min" 10
    write_value "$top_app/uclamp.boosted" 1
    write_value "$top_app/uclamp.latency_sensitive" 1
    foreground="${CPUSET_PATH}/foreground"
    write_value "$foreground/uclamp.max" 50
    write_value "$foreground/uclamp.min" 0
    write_value "$foreground/uclamp.boosted" 0
    write_value "$foreground/uclamp.latency_sensitive" 0
    background="${CPUSET_PATH}/background"
    write_value "$background/uclamp.max" max
    write_value "$background/uclamp.min" 20
    write_value "$background/uclamp.boosted" 0
    write_value "$background/uclamp.latency_sensitive" 0
    sys_bg="${CPUSET_PATH}/system-background"
    write_value "$sys_bg/uclamp.min" 0
    write_value "$sys_bg/uclamp.max" 40
    write_value "$sys_bg/uclamp.boosted" 0
    write_value "$sys_bg/uclamp.latency_sensitive" 0
    sysctl -w kernel.sched_util_clamp_min_rt_default=0
    sysctl -w kernel.sched_util_clamp_min=128
    log_info "Done."
fi

# Always allow sched boosting on top-app tasks
# Credits to tytydraco
log_info "Always allow sched boosting on top-app tasks"
write_value "$KERNEL_PATH/sched_min_task_util_for_colocation" 0
log_info "Done."

# Disable SPI CRC if supported
if [ -d "$MODULE_PATH/mmc_core" ]; then
    log_info "Disabling SPI CRC"
    write_value "$MODULE_PATH/mmc_core/parameters/use_spi_crc" 0
    log_info "Done."
fi

# Enable power efficiency
log_info "Enabling power efficiency..."
write_value "$MODULE_PATH/workqueue/parameters/power_efficient" 1
log_info "Done."

# Tweak scheduler to have less Latency
# Credits to RedHat & tytydraco & KTweak
#log_info "Tweaking scheduler to reduce latency"
#write_value "$KERNEL_PATH/sched_migration_cost_ns" 50000
#write_value "$KERNEL_PATH/sched_min_granularity_ns" 1000000
#write_value "$KERNEL_PATH/sched_wakeup_granularity_ns" 1500000

log_info "Tweaking scheduler to reduce overhead"

# Maximizing I/O Throughput
# Minimal preemption granularity for CPU-bound tasks:
write_value "$KERNEL_PATH/sched_min_granularity_ns" 10000000
# This option delays the preemption effects of decoupled workloads
# and reduces their over-scheduling. Synchronous workloads will still
# have immediate wakeup/sleep latencies.
write_value "$KERNEL_PATH/sched_wakeup_granularity_ns" 15000000
# Sets the time before the kernel considers migrating a proccess to another core
write_value "$KERNEL_PATH/sched_migration_cost_ns" 5000000

log_info "Done."

# Mglru tweaks
# Credits to Arter97
log_info "Checking if your kernel has MGLRU support..."
if [ -d "$MGLRU_PATH" ]; then
    log_info "MGLRU support found."
    log_info "Tweaking MGLRU settings..."
    write_value "$MGLRU_PATH/min_ttl_ms" 5000
    log_info "Done."
else
    log_info "MGLRU support not found."
    log_info "Aborting MGLRU tweaks..."
fi

# Zswap tweaks
log_info "Checking if your kernel supports zswap..."
if [ -d "$MODULE_PATH/zswap" ]; then
    log_info "zswap supported, applying tweaks..."
    write_value "$MODULE_PATH/zswap/parameters/compressor" lz4
    log_info "Set zswap compressor to lz4 (fastest compressor)."
    write_value "$MODULE_PATH/zswap/parameters/zpool" zsmalloc
    log_info "Set zpool to zsmalloc."
    log_info "Tweaks applied."
else
    log_info "Your kernel doesn't support zswap, aborting it..."
fi

# Apply RAM tweaks
# The stat_interval reduces jitter (Credits to kdrag0n)
# Credits to RedHat for dirty_ratio
log_info "Applying RAM Tweaks"

#log_info "Detecting if your device has less or more than 8GB of RAM"
#if [ $TOTAL_RAM -lt 8000 ]; then
#    log_info "Detected 8GB or less"
#    log_info "Applying appropriate tweaks..."
#    write_value "$MEMORY_PATH/swappiness" 60
#else
#    log_info "Detected more than 8GB"
#    log_info "Applying appropriate tweaks..."
#    write_value "$MEMORY_PATH/swappiness" 0
#fi

write_value "$MEMORY_PATH/swappiness" 20
write_value "$MEMORY_PATH/page-cluster" 0
write_value "$MEMORY_PATH/vfs_cache_pressure" 50
write_value "$MEMORY_PATH/stat_interval" 30
write_value "$MEMORY_PATH/compaction_proactiveness" 0
write_value "$MEMORY_PATH/dirty_ratio" 60
write_value "$MEMORY_PATH/page_lock_unfairness" 4
write_value "$MEMORY_PATH/watermark_boost_factor" 0

#sysctl -w vm.swappiness=20
#sysctl -w vm.page-cluster=0
#sysctl -w vm.vfs_cache_pressure=50
#sysctl -w vm.stat_interval=30
#sysctl -w vm.compaction_proactiveness=0
#sysctl -w vm.dirty_ratio=60
#sysctl -w vm.page_lock_unfairness=4
#sysctl -w vm.watermark_boost_factor=0

log_info "Done."

if $MEMORY_TWEAK_LATENCY
then
log_info "Applying Memory Latency Tweaks"
# Disable transparent huge pages
echo never > /sys/kernel/mm/transparent_hugepage/enabled
# Disable automatic NUMA memory balancing
echo 0 > /proc/sys/kernel/numa_balancing
# Disable kernel samepage merging
echo 0 > /sys/kernel/mm/ksm/run
log_info "Done."
fi

log_info "Applying Network Tweaks"
# Network tweaks
# Old
# write_value "$IPV4_PATH/tcp_tw_reuse" 1
# write_value "$IPV4_PATH/tcp_fastopen" 3
# write_value "$IPV4_PATH/tcp_no_metrics_save" 1
#

#write_value "$IPV4_PATH/tcp_low_latency" 1
#write_value "$IPV4_PATH/tcp_timestamps" 0
#write_value "$IPV4_PATH/tcp_slow_start_after_idle" 0
#write_value "$IPV4_PATH/tcp_window_scaling" 1
#write_value "$IPV4_PATH/tcp_congestion_control" "bbr"
#write_value "$IPV4_PATH/route.flush" 1

if $NETWORK_TWEAK_PERFORMANCE
then
log_info "NETWORK_TWEAK_PERFORMANCE"
sysctl -w net.ipv4.tcp_low_latency=1
sysctl -w net.ipv4.tcp_timestamps=0
sysctl -w net.ipv4.tcp_slow_start_after_idle=0
fi
if $NETWORK_TWEAK_EXTRA
then
log_info "NETWORK_TWEAK_EXTRA"
# This value overrides net.core.wmem_default used by other protocols.
# It is usually lower than net.core.wmem_default. Default: 16K
sysctl -w net.ipv4.tcp_window_scaling=1
sysctl -w net.ipv4.tcp_congestion_control=bbr
sysctl -w net.ipv4.route.flush=1
fi
if $NETWORK_TWEAK_MEMORY
then
log_info "NETWORK_TWEAK_MEMORY"
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
fi
log_info "Done."

log_info "Tweaks applied successfully. Enjoy :)"
