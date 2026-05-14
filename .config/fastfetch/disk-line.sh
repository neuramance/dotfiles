#!/usr/bin/env bash
# Emit a single DISK line: <total>  ·  <drive type + model>  ·  <usage>  ·  <fs>
set -euo pipefail

RED=$'\033[1;38;2;220;40;60m'
DIM=$'\033[0;3;38;2;130;130;130m'
RST=$'\033[0m'

if [[ "$(uname)" == "Darwin" ]]; then
  read -r total used pct < <(df -h / | awk 'NR==2 {gsub("%","",$5); print $2, $3, $5}')
  fs=$(mount | awk '$3 == "/" {gsub("[(),]","",$4); print tolower($4); exit}')
  model=$(system_profiler SPNVMeDataType 2>/dev/null | awk -F': +' '/^ +Model:/ {print $2; exit}' | xargs || true)
  kind="NVMe SSD"
  if [[ -z "$model" ]]; then
    model=$(system_profiler SPSerialATADataType 2>/dev/null | awk -F': +' '/^ +Model:/ {print $2; exit}' | xargs || true)
    [[ -n "$model" ]] && kind="SATA SSD"
  fi
else
  read -r total used pct < <(df -h --output=size,used,pcent / | awk 'NR==2 {gsub("%","",$3); print $1, $2, $3}')
  fs=$(findmnt -no FSTYPE / 2>/dev/null || echo ext4)

  source_dev=$(findmnt -no SOURCE /)
  # Walk through any LVM/partition layers to the bottom physical disk.
  phys_dev=$(lsblk -lno NAME,TYPE -s "$source_dev" 2>/dev/null | awk '$2=="disk" {print $1; exit}')
  [[ -z "${phys_dev:-}" ]] && phys_dev=$(basename "$source_dev")

  model=$(cat "/sys/block/$phys_dev/device/model" 2>/dev/null | xargs || true)
  rota=$(cat "/sys/block/$phys_dev/queue/rotational" 2>/dev/null || echo 1)
  if [[ "$phys_dev" == nvme* ]]; then
    kind="NVMe SSD"
  elif [[ "$rota" == "0" ]]; then
    kind="SATA SSD"
  else
    kind="HDD"
  fi
fi

if [[ -n "$model" ]]; then
  printf "%s%s%s  ·  %s %s  ·  %s used (%s%%)  ·  %s%s\n" "$RED" "$total" "$DIM" "$kind" "$model" "$used" "$pct" "$fs" "$RST"
else
  printf "%s%s%s  ·  %s  ·  %s used (%s%%)  ·  %s%s\n" "$RED" "$total" "$DIM" "$kind" "$used" "$pct" "$fs" "$RST"
fi
