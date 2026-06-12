#!/usr/bin/env bash
# Capture verbose DRM/DP kernel logs across session transitions to find
# which compositor handoff drops the DisplayPort link (CRTC disable +
# full link retrain) versus reusing the live mode (fast modeset). See
# thebeast.monitor.mode for why retrains cost seconds on the G95SC.
#
#   sudo scripts/drm-transition-debug.sh start
#   ...reproduce: Switch to Desktop, logout to the greeter, log back in...
#   sudo scripts/drm-transition-debug.sh stop
#
# Logging out kills the session that ran `start`; that's fine — the
# kernel log keeps accumulating, run `stop` after logging back in.
set -euo pipefail

# DRM_UT_DRIVER|KMS|ATOMIC|STATE|DP. STATE (0x40) is what makes amdgpu
# dump per-commit "crtc_state_flags: enable:.. active:.. mode_changed:..
# active_changed:.." — the line that proves which handoff component
# requests a full modeset. DRIVER (0x2) carries amdgpu's "Mode change
# not required" fast-path message.
MASK=0x156
DEBUG_PARAM=/sys/module/drm/parameters/debug
# amdgpu DC's link-training logs bypass drm.debug entirely: they are
# pr_debug with a "[HW_LINK_TRAINING]" prefix, toggled via dynamic debug.
DYNDBG_CONTROL=/sys/kernel/debug/dynamic_debug/control
START_MARK="drm-transition-debug: START"
END_MARK="drm-transition-debug: END"

[ "$(id -u)" -eq 0 ] || {
  echo "run as root: sudo $0 ${*:-start|stop}" >&2
  exit 1
}

case "${1:-}" in
start)
  echo "$MASK" >"$DEBUG_PARAM"
  if [ -w "$DYNDBG_CONTROL" ]; then
    echo 'format "HW_LINK_TRAINING" +p' >"$DYNDBG_CONTROL"
  else
    echo "warning: $DYNDBG_CONTROL not writable; link-training lines" \
      "will be missing (CONFIG_DYNAMIC_DEBUG off or debugfs unmounted)" >&2
  fi
  echo "$START_MARK" >/dev/kmsg
  cat <<EOF
drm.debug=$MASK enabled. Reproduce the black screens now (Switch to
Desktop, logout to the greeter, log back in), then run:
  sudo $0 stop
EOF
  ;;
stop)
  echo "$END_MARK" >/dev/kmsg
  echo 0 >"$DEBUG_PARAM"
  [ -w "$DYNDBG_CONTROL" ] && echo 'format "HW_LINK_TRAINING" -p' >"$DYNDBG_CONTROL"
  ts=$(date +%Y%m%d-%H%M%S)
  full="/tmp/drm-transition-$ts.full.log"
  events="/tmp/drm-transition-$ts.events.log"
  journalctl -k -b --no-pager |
    awk -v s="$START_MARK" -v e="$END_MARK" \
      'index($0, s) {on = 1} on; index($0, e) {on = 0}' >"$full"
  # HW_LINK_TRAINING = a real DP retrain happened; crtc_state_flags =
  # who asked for it (mode_changed/active_changed per commit); "Mode
  # change not required" = amdgpu's identical-stream fast path engaged.
  grep -iE 'HW_LINK_TRAINING|Mode change not required|crtc_state_flags|link.?train|retrain|dpcd|dsc|fail.?safe|disabling|enabling|connector' \
    "$full" >"$events" || true
  echo "full capture: $full ($(wc -l <"$full") lines)"
  echo "key events:   $events ($(wc -l <"$events") lines)"
  ;;
*)
  echo "usage: $0 start|stop" >&2
  exit 64
  ;;
esac
