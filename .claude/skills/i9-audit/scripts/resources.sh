#!/usr/bin/env bash
set -uo pipefail
exec 2>&1
export LC_ALL=C
shopt -s nullglob

bytes_row() {
  awk -v name="$1" -v used="$2" -v total="$3" -v pct="${4:-}" '
    function size(b,   u) {
      split("B KiB MiB GiB TiB", unit, " ")
      for (u = 1; b >= 1024 && u < 5; u++) b /= 1024
      return sprintf(b < 10 ? "%.1f %s" : "%.0f %s", b, unit[u])
    }
    BEGIN { printf "| %s | %s | %s | %s |\n", name, size(used), size(total), pct != "" ? pct : sprintf("%.0f%%", total ? 100 * used / total : 0) }'
}

echo "| Resource | Used | Total | % |"
echo "|---|---|---|---|"

read -r load _ </proc/loadavg
threads=$(nproc)
awk -v avg="$load" -v threads="$threads" 'BEGIN { printf "| CPU | load %s | %d threads | %.0f%% |\n", avg, threads, 100 * avg / threads }'

read -r mem_total mem_available swap_total swap_free < <(awk '
  /^(MemTotal|MemAvailable|SwapTotal|SwapFree):/ {kib[$1] = $2}
  END {print kib["MemTotal:"] * 1024, kib["MemAvailable:"] * 1024, kib["SwapTotal:"] * 1024, kib["SwapFree:"] * 1024}' /proc/meminfo)
bytes_row "RAM (cache excluded)" $((mem_total - mem_available)) "$mem_total"
bytes_row Swap $((swap_total - swap_free)) "$swap_total"

{
  timeout -v 10 df -B1 --output=target,size,used,pcent -x tmpfs -x devtmpfs -x squashfs -x overlay -x efivarfs | tail -n +2
  timeout -v 10 df -B1 --output=target,size,used,pcent /tmp | tail -n +2
} | while read -r target total used pct; do
  [[ $target == /tmp ]] && target="/tmp (in RAM)"
  bytes_row "Disk $target" "$used" "$total" "$pct"
done

timeout -v 20 nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits |
  while IFS=, read -r name busy used total; do
    bytes_row "GPU memory, ${name#NVIDIA } (${busy# }% busy)" $((used * 1048576)) $((total * 1048576))
  done

for device in /dev/nvme[0-9]n1; do
  wear=$(sudo -n timeout -v 20 nvme smart-log "$device" | awk -F: '/^percentage_used/ {gsub(/[ \t]/, "", $2); print $2}')
  echo "| NVMe wear, ${device#/dev/} | $wear | rated endurance | $wear |"
done
