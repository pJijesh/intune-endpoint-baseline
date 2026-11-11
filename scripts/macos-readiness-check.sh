#!/usr/bin/env bash
# macos-readiness-check.sh
#
# Read-only readiness check for a Mac against the intune-endpoint-baseline standard.
# It changes nothing, installs nothing and sends nothing off the device.
#
# Reports: macOS version, FileVault, application firewall and stealth mode, Gatekeeper,
# System Integrity Protection, screen lock, MDM and ADE enrolment state, whether the current
# user has admin rights, and whether Company Portal / Microsoft Defender are installed.
# Output is booleans, counts and versions only. No user names, serials or recovery keys.
#
# Usage:
#   ./macos-readiness-check.sh [--min-os MAJOR] [--json] [--check-updates]
#
#   --min-os MAJOR    minimum macOS major version (default 15). Keep in step with
#                     osMinimumVersion in the compliance policy.
#   --json            print JSON instead of text
#   --check-updates   also query Apple for pending updates (needs network, can be slow)
#   -h, --help        show this help
#
# Exit codes: 0 no FAIL results, 1 at least one FAIL, 2 not macOS or bad arguments.
#
# Some checks (FileVault status, firewall state) work without sudo. Where a command needs
# elevation the result is reported as WARN with the reason rather than prompting.

set -u
set -o pipefail

MIN_OS=15
AS_JSON=0
CHECK_UPDATES=0
SOCKETFILTERFW="${SOCKETFILTERFW:-/usr/libexec/ApplicationFirewall/socketfilterfw}"

usage() { sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --min-os)
      shift
      if [ $# -eq 0 ] || ! [[ "$1" =~ ^[0-9]+$ ]]; then echo "--min-os needs a whole number" >&2; exit 2; fi
      MIN_OS="$1" ;;
    --json) AS_JSON=1 ;;
    --check-updates) CHECK_UPDATES=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [ "$(uname -s)" != "Darwin" ]; then
  echo "This check runs on macOS only. Nothing was checked."
  exit 2
fi

RESULTS=()
FAILS=0
WARNS=0

# add STATUS CHECK DETAIL
add() {
  local status="$1" check="$2" detail="$3"
  RESULTS+=("${status}|${check}|${detail}")
  case "$status" in
    FAIL) FAILS=$((FAILS + 1)) ;;
    WARN) WARNS=$((WARNS + 1)) ;;
  esac
}

# macOS version
os_version="$(sw_vers -productVersion 2>/dev/null || echo unknown)"
os_major="${os_version%%.*}"
if [[ "$os_major" =~ ^[0-9]+$ ]]; then
  if [ "$os_major" -ge "$MIN_OS" ]; then
    add PASS "macOS version" "$os_version (minimum major version $MIN_OS)"
  else
    add FAIL "macOS version" "$os_version is below minimum major version $MIN_OS"
  fi
else
  add WARN "macOS version" "Could not determine version"
fi

# FileVault
fv="$(fdesetup status 2>&1 || true)"
case "$fv" in
  *"FileVault is On"*) add PASS "FileVault" "On" ;;
  *"FileVault is Off"*) add FAIL "FileVault" "Off" ;;
  *) add WARN "FileVault" "Could not determine status" ;;
esac

# Application firewall
fw="$("$SOCKETFILTERFW" --getglobalstate 2>&1 || true)"
case "$fw" in
  *"enabled"*|*"State = 1"*|*"State = 2"*) add PASS "Application firewall" "Enabled" ;;
  *"disabled"*|*"State = 0"*) add FAIL "Application firewall" "Disabled" ;;
  *) add WARN "Application firewall" "Could not determine state" ;;
esac
stealth="$("$SOCKETFILTERFW" --getstealthmode 2>&1 || true)"
case "$stealth" in
  *"is on"*|*"enabled"*) add PASS "Firewall stealth mode" "On" ;;
  *"is off"*|*"disabled"*) add WARN "Firewall stealth mode" "Off" ;;
  *) add WARN "Firewall stealth mode" "Could not determine state" ;;
esac

# Gatekeeper
gk="$(spctl --status 2>&1 || true)"
case "$gk" in
  *"assessments enabled"*) add PASS "Gatekeeper" "Enabled" ;;
  *"assessments disabled"*) add FAIL "Gatekeeper" "Disabled" ;;
  *) add WARN "Gatekeeper" "Could not determine status" ;;
esac

# System Integrity Protection
sip="$(csrutil status 2>&1 || true)"
case "$sip" in
  *"status: enabled"*) add PASS "System Integrity Protection" "Enabled" ;;
  *"status: disabled"*) add FAIL "System Integrity Protection" "Disabled" ;;
  *) add WARN "System Integrity Protection" "Could not determine status" ;;
esac

# Screen lock (per-user setting; reported for the user running the script)
sl="$(sysadminctl -screenLock status 2>&1 || true)"
case "$sl" in
  *"screenLock delay is immediate"*) add PASS "Screen lock" "Password required immediately after sleep or screen saver" ;;
  *"screenLock delay is"*) add PASS "Screen lock" "Enabled with delay: ${sl##*screenLock delay is }" ;;
  *"screenLock is off"*|*"disabled"*) add FAIL "Screen lock" "Off" ;;
  *) add WARN "Screen lock" "Could not determine status" ;;
esac

# MDM and ADE enrolment
enr="$(profiles status -type enrollment 2>&1 || true)"
case "$enr" in
  *"MDM enrollment: Yes"*) add PASS "MDM enrolment" "Enrolled" ;;
  *"MDM enrollment: No"*) add WARN "MDM enrolment" "Not enrolled" ;;
  *) add WARN "MDM enrolment" "Could not determine status" ;;
esac
case "$enr" in
  *"Enrolled via DEP: Yes"*) add INFO "Automated Device Enrolment" "Device was enrolled through automated device enrolment" ;;
  *"Enrolled via DEP: No"*) add INFO "Automated Device Enrolment" "Not enrolled through automated device enrolment" ;;
esac

# Admin rights of the current user (boolean only)
if id -Gn 2>/dev/null | tr ' ' '\n' | grep -qx admin; then
  add WARN "Current user is local admin" "Yes. Standard users are the baseline unless a documented exception exists."
else
  add PASS "Current user is local admin" "No"
fi

# Management and protection apps
if [ -d "/Applications/Company Portal.app" ]; then
  add PASS "Company Portal" "Installed"
else
  add WARN "Company Portal" "Not found in /Applications"
fi
if [ -d "/Applications/Microsoft Defender.app" ] || command -v mdatp >/dev/null 2>&1; then
  add INFO "Microsoft Defender for Endpoint" "Installed"
else
  add INFO "Microsoft Defender for Endpoint" "Not found (built-in XProtect and Gatekeeper still apply)"
fi

# Optional: pending updates
if [ "$CHECK_UPDATES" -eq 1 ]; then
  upd="$(softwareupdate --list 2>&1 || true)"
  if printf '%s' "$upd" | grep -q "No new software available"; then
    add PASS "Pending software updates" "None"
  elif printf '%s' "$upd" | grep -q "^\* "; then
    n="$(printf '%s\n' "$upd" | grep -c "^\* ")"
    add WARN "Pending software updates" "$n update(s) available"
  else
    add WARN "Pending software updates" "Could not determine"
  fi
fi

json_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

if [ "$AS_JSON" -eq 1 ]; then
  printf '{\n  "failCount": %d,\n  "warnCount": %d,\n  "results": [\n' "$FAILS" "$WARNS"
  total=${#RESULTS[@]}
  i=0
  for r in "${RESULTS[@]}"; do
    i=$((i + 1))
    IFS='|' read -r st ch de <<<"$r"
    sep=","; [ "$i" -eq "$total" ] && sep=""
    printf '    {"status": "%s", "check": "%s", "detail": "%s"}%s\n' "$st" "$(json_escape "$ch")" "$(json_escape "$de")" "$sep"
  done
  printf '  ]\n}\n'
else
  printf '%-6s %-34s %s\n' STATUS CHECK DETAIL
  for r in "${RESULTS[@]}"; do
    IFS='|' read -r st ch de <<<"$r"
    printf '%-6s %-34s %s\n' "$st" "$ch" "$de"
  done
  echo
  echo "Summary: ${FAILS} FAIL, ${WARNS} WARN. This check is read-only and changed nothing."
fi

[ "$FAILS" -gt 0 ] && exit 1
exit 0
