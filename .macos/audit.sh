#!/bin/bash
# Read-only audit of this Mac against .macos/README.md. Many checks exit nonzero
# when a setting is simply at its macOS default, so that is not treated as
# failure; a check that could not run at all is, because a silently skipped
# check is indistinguishable from a passing one.
set -u

missing=0

run() {
  local bin=${1%% *}
  if ! command -v "$bin" >/dev/null 2>&1; then
    printf '!! MISSING %s -- skipped: %s\n' "$bin" "$1"
    missing=$((missing + 1))
    return
  fi
  printf '\n== %s\n' "$1"
  eval "$1" 2>&1
}

# fd 3 keeps the check list off stdin, so no check can consume it
while IFS= read -r line <&3; do
  case $line in
    '') continue ;;
    '#'*) printf '\n\n### %s\n' "${line#\# }" ;;
    *) run "$line" ;;
  esac
done 3<<'CHECKS'
# System
sw_vers
xcode-select -p
pkgutil --pkg-info com.apple.pkg.CLTools_Executables

# Security
fdesetup status
spctl --status
csrutil status
defaults read /Library/Preferences/com.apple.FindMyMac FMMEnabled
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode
sharing -l

# Updates
softwareupdate --schedule
softwareupdate -l
defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload
defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates
defaults read /Library/Preferences/com.apple.SoftwareUpdate ConfigDataInstall
defaults read /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall

# Backups and management
tmutil status
tmutil destinationinfo
profiles status -type enrollment

# Resources
df -h /
memory_pressure
sysctl hw.memsize vm.swapusage
pmset -g custom
system_profiler SPPowerDataType | grep -A12 -E 'Health Information|Charge Information'

# Startup and services
osascript -e 'tell application "System Events" to get the name of every login item'
find ~/Library/LaunchAgents /Library/LaunchAgents /Library/LaunchDaemons -maxdepth 1 -type f 2>/dev/null | sort
launchctl print-disabled "gui/$(id -u)"
launchctl print-disabled system
systemextensionsctl list
top -l 2 -s 2 -o cpu -stats pid,command,cpu,mem -n 12

# Homebrew
brew --version
brew list --formula | wc -l
brew list --cask | wc -l
brew outdated --formula
brew outdated --cask --greedy
brew list --pinned
brew autoremove --dry-run
brew cleanup --dry-run
brew tap
brew services list
brew doctor
brew bundle check --file=~/.Brewfile --no-upgrade
otool -L /opt/homebrew/opt/libtiff/lib/libtiff.6.dylib | grep -i webp
otool -L /opt/homebrew/opt/webp/bin/cwebp | grep -i tiff

# Containers
command -v docker
docker --version

# Interaction
defaults read com.apple.finder ShowPathbar
defaults read NSGlobalDomain AppleShowAllExtensions
defaults read com.apple.finder ShowStatusBar
defaults read com.apple.dock autohide
defaults read com.apple.screencapture location
defaults read NSGlobalDomain KeyRepeat
defaults read NSGlobalDomain InitialKeyRepeat
defaults read NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled
defaults read NSGlobalDomain NSAutomaticDashSubstitutionEnabled
defaults read NSGlobalDomain NSAutomaticSpellingCorrectionEnabled
defaults read NSGlobalDomain ApplePressAndHoldEnabled
defaults read com.apple.dock autohide-delay
defaults read com.apple.dock autohide-time-modifier
defaults read com.apple.finder FXDefaultSearchScope

# Authentication
cat /etc/pam.d/sudo_local
ls -l /opt/homebrew/lib/pam/pam_reattach.so
grep -cE 'AddKeysToAgent|UseKeychain' ~/.ssh/config
ssh -G github.com | grep -i addkeystoagent
ssh-add -l

# Spotlight
mdutil -s /
ps -Ao pcpu,comm | grep -iE 'mds|mdworker' | sort -rn | head

# Apple Intelligence
defaults read com.apple.CloudSubscriptionFeatures.optIn
du -shc /System/Library/AssetsV2/com_apple_MobileAsset_UAF_FM_*

# DNS
networksetup -getdnsservers "Wi-Fi"
scutil --dns | grep -A5 'resolver #2'

# Credentials at rest
security dump-keychain 2>/dev/null | grep '"srvr"<blob>=' | sort -u

# Version control
git config --get init.defaultBranch
git config --get commit.gpgsign
git config --get gpg.format
git config --get core.pager
git config --global --get include.path
git config --list --show-origin | grep -c gitconfig.local
grep -inE 'user|email|signingkey|credential' ~/.gitconfig

# Tooling
command -v fzf zoxide delta mas fd
mas outdated
CHECKS

if [ "$missing" -gt 0 ]; then
  printf '\n%d prescribed check(s) could not run.\n' "$missing"
  exit 1
fi
