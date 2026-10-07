#!/usr/bin/env bash
set -uo pipefail
exec 2>&1
export LC_ALL=C
shopt -s nullglob

window=5
me=$(id -u)

section() { printf '\n== %s\n' "$1"; }

bounded() {
  perl -e '
    my ($seconds, @command) = @ARGV;
    my $pid = fork // die "snapshot: fork: $!\n";
    if ($pid == 0) { setpgrp; exec { $command[0] } @command or die "snapshot: $command[0]: $!\n" }
    $SIG{ALRM} = sub { kill "KILL", -$pid; print STDERR "snapshot: @command: timed out after ${seconds}s\n"; exit 124 };
    alarm $seconds;
    waitpid $pid, 0;
    exit($? & 127 ? 128 + ($? & 127) : $? >> 8);
  ' "$@"
}

section host
boot=$(sysctl -n kern.boottime | sed 's/^{ sec = \([0-9]*\),.*/\1/')
now=$(date +%s)
uptime_s=$((now - boot))
awake=$(awk -v ticks="$(sysctl -n kern.wake_abs_time)" -v rate="$(sysctl -n hw.tbfrequency)" -v woke="$(sysctl -n kern.waketime | sed 's/^{ sec = \([0-9]*\),.*/\1/')" \
  -v now="$now" -v up="$uptime_s" 'BEGIN {printf "%.0f", 100 * (ticks / rate + now - woke) / up}')
printf '%s (%s, %s), %s P + %s E cores, %s GiB, macOS %s (%s), up %dd%02dh (awake %s%% of it), load %s\n' \
  "$(bounded 10 scutil --get ComputerName)" "$(sysctl -n hw.model)" "$(sysctl -n machdep.cpu.brand_string)" \
  "$(sysctl -n hw.perflevel0.logicalcpu)" "$(sysctl -n hw.perflevel1.logicalcpu)" "$(($(sysctl -n hw.memsize) / 1073741824))" \
  "$(sw_vers -productVersion)" "$(sw_vers -buildVersion)" $((uptime_s / 86400)) $((uptime_s % 86400 / 3600)) "$awake" \
  "$(sysctl -n vm.loadavg | awk '{print $2, $3, $4}')"
echo "thermal pressure level: $(bounded 10 notifyutil -g com.apple.system.thermalpressurelevel | awk '{print $2}') (0 is nominal)"
bounded 10 pmset -g therm | grep -v '^Note: No .* has been recorded'

written() {
  bounded 10 ioreg -r -c IOBlockStorageDriver -w0 |
    awk 'match($0, /"Bytes \(Write\)"=[0-9]+/) {w = substr($0, RSTART + 16, RLENGTH - 16) + 0; if (w > max) max = w} END {printf "%.0f\n", max}'
}

section "activity over ${window}s, sampled before the other probes run"
written_before=$(written)
top_out=$(bounded 30 top -l 2 -s "$window" -stats pid,cpu,mem)
written_after=$(written)
gpu=$(bounded 10 ioreg -r -c IOAccelerator -d 1 -w0 | grep -o '"Device Utilization %"=[0-9]*' | head -1 | cut -d= -f2)
milliwatts=$(bounded 10 ioreg -rw0 -c AppleSmartBattery | grep -o '"SystemLoad"=[0-9]*' | cut -d= -f2)
launchd_jobs=$(bounded 10 launchctl list)
awk -v gpu="${gpu:-?}" -v milliwatts="$milliwatts" -v written="$((written_after - written_before))" -v window="$window" '
  /^Processes:/ {sample++}
  sample == 2 && /^CPU usage:/ {sub(/ +$/, ""); cpu = $0}
  sample == 2 && /^PhysMem:/ {memory = $0}
  sample == 2 && /^VM:/ {swaps = $(NF - 3) " " $(NF - 2) " " $(NF - 1) " " $NF}
  END {
    watts = milliwatts == "" ? "unavailable" : sprintf("%.1f W", milliwatts / 1000)
    printf "%s; disk writes %.1f MB/s\nGPU %s%% at the end of the window; system power %s (battery telemetry, refreshed about once a minute)\n", cpu, written / window / 1e6, gpu, watts
    printf "%s\nsince boot: %s\n", memory, swaps
  }' <<<"$top_out"
echo "process trees: each child of launchd, herdr, tmux or a terminal with its descendants. NOW is % of one core over the window,"
echo "AVG the lifetime CPU of its live processes over the root's age (sleep included), MiB the memory footprint Activity Monitor shows."
echo "A login or shell root is labelled by its largest descendant, after '>'."
echo " NOW%  AVG%    MiB    PID USER         AGE  ROOT"
{
  printf '%s\n' "$top_out" | sed 's/^/top /'
  awk 'NR > 1 && $1 ~ /^[0-9]+$/ {print "job", $1}' <<<"$launchd_jobs"
  bounded 10 ps -axo pid=,ppid=,uid=,user=,etime=,time=,args= | sed 's/^/ps /'
} | awk -v me="$me" '
  function seconds(t,   days, f, n) {
    days = 0
    if (t ~ /-/) { days = t; sub(/-.*/, "", days); sub(/^[^-]*-/, "", t) }
    n = split(t, f, ":")
    return days * 86400 + (n == 3 ? f[1] * 3600 + f[2] * 60 + f[3] : f[1] * 60 + f[2])
  }
  function mebibytes(m,   unit) {
    unit = m; gsub(/[0-9.+-]/, "", unit); m += 0
    return unit == "K" ? m / 1024 : unit == "M" ? m : unit == "G" ? m * 1024 : unit == "T" ? m * 1048576 : m / 1048576
  }
  function walk(p, r,   kids, n, i) {
    now[r] += cpu[p]; life[r] += used[p]; mib[r] += mem[p]
    if (hub[p]) return
    n = split(children[p], kids, " ")
    for (i = 1; i <= n; i++) if (!hub[kids[i]]) walk(kids[i], r)
  }
  function label(p,   start, kids, n, i, best) {
    start = p
    while (cmd[p] ~ /^(\/usr\/bin\/login |-?(\/bin\/)?(zsh|bash|sh|fish)$)/) {
      n = split(children[p], kids, " "); best = ""
      for (i = 1; i <= n; i++) if (best == "" || mem[kids[i]] > mem[best]) best = kids[i]
      if (best == "") break
      p = best
    }
    owner = user[p]
    return (p == start ? "" : "> ") cmd[p]
  }
  function age(s) {
    return s >= 86400 ? sprintf("%dd%02dh", s / 86400, s % 86400 / 3600) : sprintf("%dh%02dm", s / 3600, s % 3600 / 60)
  }
  $1 == "top" && $2 == "Processes:" {sample++}
  $1 == "top" && $2 ~ /^[0-9]+$/ && sample == 2 {cpu[$2] = $3; mem[$2] = mebibytes($4)}
  $1 == "job" {job[$2] = 1}
  $1 == "ps" {
    pid = $2; parent[pid] = $3; uid[pid] = $4; user[pid] = $5; elapsed[pid] = seconds($6); used[pid] = seconds($7)
    children[$3] = children[$3] " " pid
    $1 = $2 = $3 = $4 = $5 = $6 = $7 = ""
    cmd[pid] = substr($0, 8)
    if (pid == 1 || cmd[pid] ~ /^([^ ]*\/herdr server$|tmux|\/Users\/[^\/]+\/Library\/Application Support\/iTerm2\/iTermServer)|\/(Terminal|Ghostty)\.app\/Contents\/MacOS\/[^\/]*$/) hub[pid] = 1
  }
  END {
    printf "%5.0f %5s %6.0f %6s %-9.9s %7s  %s\n", cpu[0], "-", mem[0], 0, "root", "-", "kernel_task (the kernel; not in ps)"
    for (pid in parent) if (pid != 1 && (hub[parent[pid]] || hub[pid])) { root[pid] = 1; walk(pid, pid) }
    for (pid in root) {
      detached = parent[pid] == 1 && uid[pid] == me && !(pid in job) && cmd[pid] !~ /\.(app|appex|xpc)\// && cmd[pid] !~ /^\/(System|usr|Library\/Apple)\//
      average = elapsed[pid] ? 100 * life[pid] / elapsed[pid] : 0
      if (now[pid] < 5 && average < 5 && mib[pid] < 500 && !detached) continue
      name = label(pid)
      printf "%5.0f %5.1f %6.0f %6s %-9.9s %7s  %s%.110s\n", now[pid], average, mib[pid], pid, owner, age(elapsed[pid]),
        detached ? "[detached] " : hub[pid] ? "[hub] " : "", name
    }
  }' | sort -rn
echo "zombies: $(bounded 10 ps -axo stat= | grep -c '^Z')"

section memory
echo "pressure level $(sysctl -n kern.memorystatus_vm_pressure_level) (1 normal, 2 warning, 4 critical); $(memory_pressure -Q | grep -o 'free percentage: .*')"
echo "swap: $(sysctl -n vm.swapusage)"

section power
bounded 10 pmset -g batt | sed -n '1p; 2s/^ *-InternalBattery-0 ([^)]*)[[:space:]]*/battery /p'
bounded 20 system_profiler SPPowerDataType | awk -F': ' '
  /^ +(Cycle Count|Condition|Maximum Capacity):/ {sub(/^ +/, "", $1); line = line $1 " " $2 "; "} END {print line}'
bounded 10 pmset -g custom | awk '
  /^[A-Z].*:$/ {if (line) print line; line = "  " $0; next}
  $1 ~ /^(sleep|displaysleep|disksleep|powernap|powermode|standby|tcpkeepalive|ttyskeepawake|womp)$/ {line = line " " $1 "=" $2}
  END {print line}'
echo "sleep assertions by process:"
bounded 10 pmset -g assertions | awk '
  /^Listed by owning process:/ {on = 1; next}
  /^Kernel Assertions:/ {on = 0}
  on && $1 == "pid" {sub(/ \[0x[0-9a-fA-F]+\]/, ""); print}' | tr -s ' '
bounded 30 pmset -g log | awk -v since="$(date -v-24H '+%Y-%m-%d %H:%M:%S')" '
  $1 " " $2 < since {next}
  {split($0, part, "\t"); type = part[1]; sub(/^[^ ]+ [^ ]+ [^ ]+ /, "", type); sub(/ +$/, "", type)}
  type != "Sleep" && type != "DarkWake" && type != "Wake" {next}
  {
    charge = match($0, /Charge:[0-9]+%/) ? substr($0, RSTART + 7, RLENGTH - 8) : ""
    on_battery = $0 ~ /Using (Batt|BATT)/
    secs = match($0, /[0-9]+ secs/) ? substr($0, RSTART, RLENGTH) + 0 : 0
  }
  !on_battery || charge == "" {session = 0}
  type == "Sleep" {sleeps++; asleep += secs; if (!session && on_battery && charge != "") {session = 1; start = charge; span = 0}}
  type == "DarkWake" {darkwakes++}
  session && type != "Wake" {span += secs}
  session && type == "Wake" {lost += start - charge; battery_hours += span / 3600; session = 0}
  END {
    printf "last 24h: %d sleeps totalling %.1f h, %d dark wakes; on battery, %d%% charge lost over %.1f h from sleep to wake", sleeps, asleep / 3600, darkwakes, lost, battery_hours
    print battery_hours ? sprintf(" (%.2f%% per hour)", lost / battery_hours) : ""
  }'

section reports
echo "diagnostic reports from the last 7 days (count, process, kind, latest):"
bounded 30 find "$HOME/Library/Logs/DiagnosticReports" /Library/Logs/DiagnosticReports -maxdepth 1 -type f -mtime -7 \
  \( -name '*.ips' -o -name '*.diag' -o -name '*.panic' \) |
  while IFS= read -r file; do
    name=${file##*/}
    case $name in
      *.panic) kind=panic ;;
      *) kind=$(sed -nE '1s/.*"bug_type":"([0-9]+)".*/bug_type \1/p; s/^Event: +//p' "$file" | head -1) ;;
    esac
    [[ $kind == "bug_type 309" ]] && kind=crash
    [[ -n $kind ]] && printf '%s\t%s\n' "$(sed -E 's/[-_]([0-9]{4}-[0-9]{2}-[0-9]{2})-([0-9]{2})([0-9]{2})[0-9]{2}.*/\t\1 \2:\3/' <<<"$name")" "$kind"
  done | awk -F'\t' '
    {key = $1 "\t" $3; n[key]++; if ($2 > last[key]) last[key] = $2}
    END {for (key in n) printf "%6d  %s\t%s\n", n[key], key, last[key]; if (!NR) print "     0"}' | sort -rn

section launchd
echo "jobs installed as plists (domain, state, runs since loaded, last exit):"
for plist in "$HOME"/Library/LaunchAgents/*.plist /Library/LaunchAgents/*.plist /Library/LaunchDaemons/*.plist; do
  domain=gui/$me
  [[ $plist == /Library/LaunchDaemons/* ]] && domain=system
  note=""
  if label=$(plutil -extract Label raw "$plist" 2>/dev/null); then
    program=$(plutil -extract Program raw "$plist" 2>/dev/null || plutil -extract ProgramArguments.0 raw "$plist" 2>/dev/null)
    [[ -z $program || -e $program ]] || note=" MISSING PROGRAM $program"
  else
    label=$(basename "$plist" .plist)
    note=" (plist unreadable)"
  fi
  printf '  %-42s %-6s %s%s\n' "$label" "${domain%%/*}" "$(bounded 10 launchctl print "$domain/$label" 2>&1 | awk -F' = ' '
    NR == 1 {first = $0}
    /Could not find service/ {missing = 1}
    /^\t(state|runs|last exit code) = / {sub(/^\t/, "", $1); line = line $1 "=" $2 " "}
    END {print line ? line : missing ? "not loaded" : first}')" "$note"
done
echo "other loaded jobs whose last exit failed:"
awk 'NR > 1 && $2 != 0 && $2 != "-" && $3 !~ /^(com\.apple\.|io\.github\.neuramance\.)/ {printf "  %s status=%s pid=%s\n", $3, $2, $1; n++}
  END {if (!n) print "  none"}' <<<"$launchd_jobs"

section listeners
echo "TCP listeners (scope, address, owner, port, established connections), loopback grouped by owner:"
bounded 10 netstat -anv -p tcp | awk -v OFS='\t' '
  $1 !~ /^tcp/ {next}
  {port = $4; sub(/.*\./, "", port); host = $4; sub(/\.[^.]*$/, "", host)}
  $6 == "ESTABLISHED" {conns[host " " port]++}
  $6 == "LISTEN" {
    owner = $11; for (i = 12; i <= NF - 8; i++) owner = owner " " $i
    bound[host " " port] = 1
    listener[(host ~ /^(127\.|::1$)/ ? "loopback" : "exposed") OFS owner OFS host OFS port] = host " " port
  }
  END {
    for (key in listener) {
      split(listener[key], address, " "); n = 0
      for (c in conns) {
        split(c, local, " ")
        if (local[2] == address[2] && (c == listener[key] || address[1] == "*" && !(c in bound))) n += conns[c]
      }
      print key, n
    }
  }' |
  sort -t$'\t' -k1,1 -k2,2 -k4,4n | awk -F'\t' '
    function flush() {
      if (owner != "") printf "loopback  %-26s ports %s conns=%d\n", owner, ranges (first == last ? first : first "-" last), total
    }
    $1 == "exposed" {printf "EXPOSED   %-26s %-6s port %s conns=%d\n", $2, $3, $4, $5; next}
    $2 != owner {flush(); owner = $2; ranges = first = last = ""; total = 0}
    $4 == last {next}
    {total += $5}
    last != "" && $4 == last + 1 {last = $4; next}
    {if (first != "") ranges = ranges (first == last ? first : first "-" last) ","; first = last = $4}
    END {flush()}'
echo "UDP sockets bound to a fixed port on a non-loopback address:"
bounded 10 netstat -anv -p udp | awk '
  $1 ~ /^udp/ && $5 == "*.*" && $4 !~ /^(127\.0\.0\.1|::1)\./ && $4 !~ /\.\*$/ {
    owner = $10; for (i = 11; i <= NF - 8; i++) owner = owner " " $i
    print "  " $4, owner
  }' | sort -u

section security
echo "FileVault: $(bounded 10 fdesetup status | head -1) $(bounded 10 csrutil status) Gatekeeper: $(bounded 10 spctl --status)"
bounded 10 /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate --getstealthmode --getallowsigned | paste -sd' ' -
echo "screen saver idleTime: $(bounded 10 defaults -currentHost read com.apple.screensaver idleTime 2>&1 | tail -1) (0 is never);\
 $(bounded 10 sysadminctl -screenLock status 2>&1 | sed -n 's/.*screenLock delay is/screen lock delay/p')"
echo "sshd effective settings: $(bounded 10 /usr/sbin/sshd -G |
  awk '$1 ~ /^(passwordauthentication|kbdinteractiveauthentication|permitrootlogin)$/ {printf "%s=%s ", $1, $2}')"
destinations=$(bounded 30 tmutil destinationinfo 2>&1)
if grep -q '^Name' <<<"$destinations"; then
  echo "Time Machine destinations: $(awk -F' *: ' '/^Name/ {print $2}' <<<"$destinations" | paste -sd, -); latest backup: $(bounded 30 tmutil latestbackup 2>&1 | head -1)"
else
  echo "Time Machine: $destinations"
fi
bounded 10 defaults read /Library/Preferences/com.apple.SoftwareUpdate | awk '
  $1 ~ /^(AutomaticCheckEnabled|AutomaticDownload|AutomaticallyInstallMacOSUpdates|CriticalUpdateInstall|ConfigDataInstall)$/ {
    sub(/;$/, "", $3); line = line " " $1 "=" $3
  }
  END {print "automatic updates:" line}'
echo "pending software updates:"
bounded 90 softwareupdate -l | sed -n 's/^[[:space:]]*Title: /  /p; s/^No new software available.*/  none/p'

section disk
bounded 10 df -h -T apfs,hfs,exfat,msdos | awk 'NR == 1 || / \/System\/Volumes\/Data$/ || / \/Volumes\//'
bounded 20 diskutil info / | awk -F': +' '
  /Container (Total|Free) Space|SMART Status/ {sub(/^ +/, "", $1); sub(/ \(.*/, "", $2); line = line $1 ": " $2 "; "} END {print line}'
echo "local APFS snapshots of /: $(bounded 30 tmutil listlocalsnapshots / | grep -c '^com\.apple')"
bounded 10 ioreg -r -c IOBlockStorageDriver -w0 | awk -v days="$uptime_s" '
  match($0, /"Bytes \(Write\)"=[0-9]+/) {w = substr($0, RSTART + 16, RLENGTH - 16) + 0; if (w > written) written = w}
  match($0, /"Bytes \(Read\)"=[0-9]+/) {r = substr($0, RSTART + 15, RLENGTH - 15) + 0; if (r > read) read = r}
  END {days /= 86400; printf "busiest disk since boot: %.0f GB read, %.0f GB written, %.0f GB written per day\n", read / 1e9, written / 1e9, written / 1e9 / days}'

section docker
docker_status=$(bounded 20 docker desktop status --format json | jq -r '.Status // empty')
echo "Docker Desktop engine: ${docker_status:-unknown} (stopped includes Resource Saver's idle shutdown)"
settings="$HOME/Library/Group Containers/group.com.docker/settings-store.json"
[[ -f $settings ]] && echo "non-default VM settings: $(jq -c 'with_entries(select(.key | test("(?i)memory|cpu|swap|disk|saver|pause|virtualiz|rosetta|vmm|kube")))' "$settings")"
for image in "$HOME"/Library/Containers/com.docker.docker/Data/vms/*/data/Docker.raw; do
  printf '%s: %s GiB allocated of %s GiB apparent\n' "$image" "$(bounded 30 du -k "$image" | awk '{printf "%.0f", $1 / 1048576}')" \
    "$(stat -f %z "$image" | awk '{printf "%.0f", $1 / 1073741824}')"
done
if [[ $docker_status == running ]]; then
  bounded 30 docker system df
  bounded 30 docker ps -a --format '{{.Names}}\t{{.Status}}\t{{.Image}}'
  containers=$(bounded 30 docker ps -aq | paste -sd' ' -)
  if [[ -n $containers ]]; then
    echo "containers restarted, OOM-killed, or running a non-arm64 image (emulated):"
    bounded 30 docker inspect -f '{{.Name}} {{.RestartCount}} {{.State.OOMKilled}} {{.Image}}' $containers |
      while read -r name restarts oom image; do
        arch=$(bounded 10 docker image inspect -f '{{.Architecture}}' "$image")
        [[ $restarts == 0 && $oom == false && $arch == arm64 ]] || echo "  $name restarts=$restarts oomkilled=$oom arch=$arch"
      done
  fi
  bounded 30 docker stats --no-stream --format '{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}'
  bounded 30 docker system df -v --format json | jq -r '
    (.Images[] | select(.Containers == "0") | "unused image   \(.Size)\t\(.Repository):\(.Tag)\t\(.CreatedSince)"),
    (.Volumes[] | select(.Links == "0") | "unused volume  \(.Size)\t\(.Name)")'
fi

section worktrees
extra=$(for repo in "$HOME"/code/*/; do
  [[ -d ${repo}.git ]] || continue
  bounded 10 git -C "$repo" worktree list --porcelain |
    awk -v repo="${repo%/}" '/^worktree / {n++} /^prunable/ {p++} END {if (n > 1 || p) printf "%-44s worktrees=%d prunable=%d\n", repo, n, p}'
done)
echo "${extra:-no repository has extra or prunable worktrees}"
