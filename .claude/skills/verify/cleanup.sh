#!/usr/bin/env bash
# Stops verify instances that a crashed or killed run.sh left behind. It never touches the evidence in .verify/.
# It stops only the private KWin (socket zsfps-verify-*) and the Godot that runs driver.gd, by PID.
set -uo pipefail
# pgrep -x matches the executable name only, so a shell whose command line names these patterns is never hit.
for pid in $(pgrep -x godot) $(pgrep -x kwin_wayland); do
	cmdline="$(tr '\0' ' ' </proc/"$pid"/cmdline 2>/dev/null)"
	if [[ "$cmdline" == *"verify/driver.gd -- "* || "$cmdline" == *"--socket zsfps-verify-"* ]]; then
		echo "stop $pid: ${cmdline:0:120}"
		kill "$pid" 2>/dev/null
	fi
done
sleep 1
rm -f "${XDG_RUNTIME_DIR:?}"/zsfps-verify-*
echo "cleanup done. Evidence kept in $(cd "$(dirname "$0")/../../.." && pwd)/.verify"
