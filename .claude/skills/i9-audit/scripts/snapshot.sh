#!/usr/bin/env bash
set -uo pipefail
exec 2>&1
export LC_ALL=C
shopt -s nullglob

section() { printf '\n== %s\n' "$1"; }

if ! sudo -n true 2>/dev/null; then
  echo "snapshot: needs passwordless sudo; without it other users' processes, sockets and logs are invisible"
  exit 1
fi

section host
printf '%s, %s, kernel %s, %s threads, load %s\n' "$(hostname)" "$(uptime -p)" "$(uname -r)" "$(nproc)" "$(cut -d' ' -f1-3 /proc/loadavg)"
if [[ -e /run/reboot-required ]]; then
  echo "reboot required by: $(paste -sd' ' /run/reboot-required.pkgs)"
else
  echo "reboot required: no"
fi
if upgrades=$(timeout -v 60 apt-get -s -o Debug::NoLocking=1 dist-upgrade); then
  awk '/^Inst / {n++; s += /-security/} END {printf "upgradable packages: %d (security %d)\n", n, s}' <<<"$upgrades"
fi
sudo -n timeout -v 60 needrestart -b -r l | grep -E '^NEEDRESTART-(KSTA|SVC)'
sudo -n timeout -v 30 journalctl --list-boots -q --no-pager | tail -4
echo "previous boot ended with: $(sudo -n timeout -v 30 journalctl -b -1 -q -n 1 -o cat)"

section pressure
for resource in cpu memory io; do
  printf '%-6s %s\n' "$resource" "$(paste -sd' ' "/proc/pressure/$resource" | sed 's/ total=[0-9]*//g')"
done
free -h
swapon --noheadings --show=NAME,SIZE,USED

section cpu-now
timeout -v 10 top -bn2 -d1 -w512 -o %CPU |
  awk '/^top -/ {frame++} frame == 2 && $1 ~ /^[0-9]+$/ && $12 != "top" && shown++ < 8 {printf "%6s%% %8s %-9s %s\n", $9, $1, $2, $12}'

section memory
timeout -v 10 ps -eo user=,rss= |
  awk '{kib[$1] += $2} END {for (u in kib) if (kib[u] >= 102400) printf "%7.0f MiB  %s\n", kib[u] / 1024, u}' | sort -rn
timeout -v 10 df -h -t tmpfs | awk 'NR == 1 || $3 ~ /G$/'
sudo -n timeout -v 60 du -xh -d 1 -t 100M /tmp | sort -h -r | head -11

section process-trees
echo "    MiB      PID USER         AGE  ROOT (a child of init, user systemd, herdr server or containerd-shim)"
timeout -v 10 ps -eo pid=,ppid=,uid=,user=,etimes=,rss=,args= | awk '
  {
    pid = $1; parent[pid] = $2; uid[pid] = $3; user[pid] = $4; age[pid] = $5; rss[pid] = $6
    children[$2] = children[$2] " " pid
    $1 = $2 = $3 = $4 = $5 = $6 = ""
    cmd[pid] = substr($0, 7)
    if (pid == 1 || cmd[pid] ~ /systemd --user$|herdr server$|containerd-shim/) hub[pid] = 1
  }
  function tree(p,   kids, n, i, sum) {
    sum = rss[p]
    n = split(children[p], kids, " ")
    for (i = 1; i <= n; i++) sum += tree(kids[i])
    return sum
  }
  function since(s) {
    return s >= 86400 ? sprintf("%dd%02dh", s / 86400, s % 86400 / 3600) : sprintf("%dh%02dm", s / 3600, s % 3600 / 60)
  }
  END {
    for (pid in parent) {
      if (!hub[parent[pid]] || hub[pid]) continue
      mib = tree(pid) / 1024
      detached = parent[pid] == 1 && uid[pid] >= 1000
      if (mib >= 100 || detached)
        printf "%7.0f %8s %-9s %7s  %s%.110s\n", mib, pid, user[pid], since(age[pid]), detached ? "[detached] " : "", cmd[pid]
    }
  }' | sort -rn
echo "zombies: $(timeout -v 10 pgrep -c -r Z)"

section listeners
{ sudo -n timeout -v 10 ss -tulnpH; sudo -n timeout -v 10 ss -tnpiOH state established; } | awk '
  function owner(   rest, name) {
    if (!match($0, /users:\(\("/)) return "-"
    rest = substr($0, RSTART + RLENGTH)
    name = rest
    sub(/",pid=.*/, "", name)
    match(rest, /pid=[0-9]+/)
    return name "/" substr(rest, RSTART + 4, RLENGTH - 4)
  }
  function port(address) { sub(/.*:/, "", address); return address }
  function host(address) { sub(/:[^:]*$/, "", address); return address }
  $1 ~ /^(tcp|udp)$/ {
    key = $1 " " port($5)
    addrs[key] = (key in addrs) ? addrs[key] "," host($5) : host($5)
    proc[key] = owner()
    if ($1 == "tcp") listening[port($5)] = 1
    next
  }
  {
    idle = ""
    for (i = 5; i <= NF; i++)
      if ($i ~ /^last(snd|rcv):/) { ms = $i; sub(/.*:/, "", ms); if (idle == "" || ms + 0 < idle) idle = ms + 0 }
    sock[$3 "|" $4] = owner()
    quiet[$3 "|" $4] = idle
  }
  END {
    for (t in sock) {
      split(t, ends, "|")
      p = port(ends[1])
      if (!(p in listening)) continue
      conns[p]++
      if (quiet[t] != "" && (!(p in least) || quiet[t] < least[p])) least[p] = quiet[t]
      reverse = ends[2] "|" ends[1]
      who = (reverse in sock) ? sock[reverse] : host(ends[2])
      sub(/\/[0-9]+$/, "", who)
      if (index(clients[p] " ", " " who " ") == 0) clients[p] = clients[p] " " who
    }
    for (key in addrs) {
      split(key, k, " ")
      line = sprintf("%-4s %6s  %-34s %-24s", k[1], k[2], addrs[key], proc[key])
      if (k[1] == "tcp") line = line sprintf(" conns=%d", conns[k[2]])
      if (conns[k[2]]) line = line sprintf(" idle=%ds from:%s", least[k[2]] / 1000, clients[k[2]])
      print line
    }
  }' | sort -k1,1 -k2,2n

section services
for scope in --system --user; do
  failed=$(timeout -v 20 systemctl "$scope" --failed --no-legend --plain | awk '{print $1}' | paste -sd' ')
  echo "${scope#--} failed units: ${failed:-none}"
  timeout -v 20 systemctl "$scope" show '*.service' -p Id -p NRestarts | paste -d' ' - - - |
    awk -v scope="${scope#--}" '$2 != "NRestarts=0" {print scope, "restarted:", $1, $2}'
done

section timers
for scope in --system --user; do
  timeout -v 20 systemctl "$scope" list-timers --all --output=json | jq -r '
    def span: if . == null then "-" elif . >= 86400 then "\(. / 86400 | floor)d" elif . >= 3600 then "\(. / 3600 | floor)h"
      elif . >= 60 then "\(. / 60 | floor)m" else "\(. | floor)s" end;
    .[] | [.unit, .activates, (if .last > 0 then now - .last / 1e6 else null end | span),
      (if .next > 0 then .next / 1e6 - now else null end | span)] | @tsv' |
    while IFS=$'\t' read -r timer service ago next; do
      printf '%-6s %-34s ago=%-4s next=%-4s %s\n' "${scope#--}" "$timer" "$ago" "$next" \
        "$(timeout -v 10 systemctl "$scope" show -p ActiveState -p Result -p ExecMainStatus "$service" | paste -sd' ')"
    done
done

section journal
sudo -n timeout -v 30 journalctl --disk-usage
echo "this boot: error-priority messages, plus lower-priority ones that say error, fatal, traceback or panic (count, source, latest):"
{
  sudo -n timeout -v 30 journalctl -b -p err -q -o json --output-fields=UNIT,USER_UNIT,SYSLOG_IDENTIFIER,_COMM,MESSAGE
  sudo -n timeout -v 30 journalctl -b -p 4..6 -q -o json --output-fields=UNIT,USER_UNIT,SYSLOG_IDENTIFIER,_COMM,MESSAGE \
    --grep '(?i)\b(error|fatal|traceback|panic)\b'
} | jq -r 'select(.SYSLOG_IDENTIFIER != "sudo")
    | "\([.UNIT, .USER_UNIT, .SYSLOG_IDENTIFIER, ._COMM, "?"] | map(select(. != null and . != "")) | first)\t\(.MESSAGE | if type == "string" then gsub("\\s+"; " ") else "(binary)" end)"' |
  awk -F'\t' '{n[$1]++; last[$1] = $2} END {for (k in n) printf "%6d %s: %.150s\n", n[k], k, last[k]; if (!NR) print "     0"}' |
  sort -rn | head -20
echo "kernel fault signatures this boot:"
faults=$(sudo -n timeout -v 30 journalctl -k -b -q --no-pager -o cat |
  grep -iE 'oom-kill|out of memory|killed process|machine check|hardware error|i/o error|nvme.*(timeout|reset|abort)|temperature above threshold|clock throttled|segfault|blocked for more than|soft lockup|call trace')
echo "${faults:-none}" | tail -8

section disk
timeout -v 10 df -hT -x tmpfs -x devtmpfs -x squashfs -x overlay -x efivarfs
timeout -v 10 df -i -x tmpfs -x devtmpfs -x squashfs -x overlay -x efivarfs
echo "directories of 1G or more, depth 3, root filesystem:"
sudo -n timeout -v 120 du -xh -d 3 -t 1G / | sort -h -r
for device in /dev/nvme[0-9]n1; do
  printf '%s: ' "$device"
  sudo -n timeout -v 20 nvme smart-log "$device" | awk -F: '
    /^(critical_warning|temperature|available_spare|available_spare_threshold|percentage_used|media_errors|unsafe_shutdowns)[ \t]/ {
      gsub(/[ \t]/, "", $1); sub(/^[ \t]+/, "", $2); sub(/ \(.*/, "", $2); printf "%s=%s ", $1, $2
    }
    END {print ""}'
done

section docker
timeout -v 30 docker system df
timeout -v 30 docker ps -a --format '{{.Names}}\t{{.Status}}\t{{.Image}}'
mapfile -t containers < <(timeout -v 30 docker ps -aq)
if ((${#containers[@]})); then
  timeout -v 30 docker inspect -f '{{.Name}} restarts={{.RestartCount}} oomkilled={{.State.OOMKilled}}' "${containers[@]}" |
    grep -v 'restarts=0 oomkilled=false'
fi
timeout -v 30 docker stats --no-stream --format '{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}'
timeout -v 30 docker system df -v --format json | jq -r '
  (.Images[] | select(.Containers == "0") | "unused image   \(.Size)\t\(.Repository):\(.Tag)\t\(.CreatedSince)"),
  (.Volumes[] | select(.Links == "0") | "unused volume  \(.Size)\t\(.Name)")'

section gpu
timeout -v 20 nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total,power.draw --format=csv,noheader
timeout -v 20 nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader

section network
ip -o route show default
uplink=$(ip -o route show default | awk '{print $5; exit}')
printf '%s: ' "$uplink"
timeout -v 5 iw dev "$uplink" link | awk '/signal|tx bitrate/ {$1 = $1; printf "%s; ", $0} END {print ""}'
echo "wifi disconnects this boot: $(sudo -n timeout -v 30 journalctl -b -q -t wpa_supplicant -o cat | grep -c CTRL-EVENT-DISCONNECTED)"
timeout -v 10 networkctl list --no-pager --no-legend | awk '$2 !~ /^(veth|br-)/'
sudo -n timeout -v 10 ufw status
printf 'DOCKER-USER DROP rules: ipv4 %s, ipv6 %s\n' \
  "$(sudo -n timeout -v 10 iptables -S DOCKER-USER | grep -c DROP)" "$(sudo -n timeout -v 10 ip6tables -S DOCKER-USER | grep -c DROP)"
printf 'ingress-guard %s: ' "$(timeout -v 10 systemctl is-active ingress-guard)"
sudo -n timeout -v 10 nft list table inet ingress_guard | tr -s '[:space:]' ' '
echo
sudo -n timeout -v 10 tailscale serve status
timeout -v 10 chronyc -n tracking | grep -E '^(Reference ID|System time|Leap status)'

section worktrees
extra=$(for repo in "$HOME"/code/*/ /srv/*/ /srv/*/*/; do
  [[ -e ${repo}.git ]] || continue
  timeout -v 10 git -C "$repo" worktree list --porcelain |
    awk -v repo="${repo%/}" '/^worktree / {n++} /^prunable/ {p++} END {if (n > 1 || p) printf "%-44s worktrees=%d prunable=%d\n", repo, n, p}'
done)
echo "${extra:-no repository has extra or prunable worktrees}"
