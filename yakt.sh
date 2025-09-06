#!/system/bin/sh

# YAKT v801
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
log_info "Starting YAKT v801"
log_info "Build Date: 06/06/2024"
log_info "Author: @NotZeetaa (Github)"
log_info "Device: $(getprop ro.product.system.model)"
log_info "Brand: $(getprop ro.product.system.brand)"
log_info "Kernel: $(uname -r)"
log_info "ROM Build Type: $(getprop ro.system.build.type)"
log_info "Android Version: $ANDROID_VERSION"

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

# Disable SPI CRC if supported
if [ -d "$MODULE_PATH/mmc_core" ]; then
    log_info "Disabling SPI CRC"
    write_value "$MODULE_PATH/mmc_core/parameters/use_spi_crc" 0
    log_info "Done."
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

log_info "NETWORK_TWEAK_PERFORMANCE"
write_value "$IPV4_PATH/tcp_low_latency" 1
write_value "$IPV4_PATH/tcp_timestamps" 0
write_value "$IPV4_PATH/tcp_slow_start_after_idle" 0

# Always allow sched boosting on top-app tasks
write_value "/proc/sys/kernel/sched_min_task_util_for_colocation" 0

# Improve real time latencies by reducing the scheduler migration time
write_value "/proc/sys/kernel/sched_nr_migrate" 32

# Disable scheduler statistics to reduce overhead
write_value "/proc/sys/kernel/sched_schedstats" 0

# Disable unnecessary printk logging
write_value "/proc/sys/kernel/printk_devkmsg" off

# Update /proc/stat less often to reduce jitter
write_value "/proc/sys/vm/stat_interval" 10

# Enable Explicit Congestion Control
write_value "/proc/sys/net/ipv4/tcp_ecn" 1

# Enable fast socket open for receiver and sender
write_value "/proc/sys/net/ipv4/tcp_fastopen" 3

# Disable SYN cookies
write_value "/proc/sys/net/ipv4/tcp_syncookies" 0

for queue in /sys/block/*/queue
do
  # Do not use I/O as a source of randomness
	write_value "$queue/add_random" 0

	# Disable I/O statistics accounting
	write_value "$queue/iostats" 0

	# Reduce heuristic read-ahead in exchange for I/O latency
	write_value "$queue/read_ahead_kb" 128

	# Reduce the maximum number of I/O requests in exchange for latency
	write_value "$queue/nr_requests" 64
done

# Disable watchdog
log_info "Disable watchdog..."
write_value "$MODULE_PATH/workqueue/parameters/watchdog_thresh" 0
log_info "Done."

# Always return success, even if the last write_value fails
exit 0
