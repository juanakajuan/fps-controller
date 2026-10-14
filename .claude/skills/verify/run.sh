#!/usr/bin/env bash
# Plays one scenario in the real game window inside a private headless KWin, and keeps the evidence.
# Usage: .claude/skills/verify/run.sh <scenario-file> [evidence-dir]
set -euo pipefail
skill_dir="$(cd "$(dirname "$0")" && pwd)"
project="$(cd "$skill_dir/../../.." && pwd)"
scenario="$(realpath "$1")"
evidence="$(realpath -m "${2:-$project/.verify/$(date +%Y%m%d-%H%M%S)-$(basename "$scenario" .txt)}")"
socket="zsfps-verify-$$"
mkdir -p "$evidence"

kwin_pid=""
godot_pid=""
cleanup() {
	[[ -n "$godot_pid" ]] && kill "$godot_pid" 2>/dev/null || true
	[[ -n "$kwin_pid" ]] && kill "$kwin_pid" 2>/dev/null || true
	wait 2>/dev/null || true
	rm -f "$XDG_RUNTIME_DIR/$socket" "$XDG_RUNTIME_DIR/$socket.lock"
}
trap cleanup EXIT INT TERM

kwin_wayland --virtual --no-lockscreen --no-global-shortcuts --socket "$socket" --width 1600 --height 900 >"$evidence/kwin.log" 2>&1 &
kwin_pid=$!
for _ in $(seq 1 100); do
	[[ -S "$XDG_RUNTIME_DIR/$socket" ]] && break
	sleep 0.1
done
if [[ ! -S "$XDG_RUNTIME_DIR/$socket" ]]; then
	echo "FAIL: KWin did not open $socket. See $evidence/kwin.log"
	exit 2
fi

status=0
WAYLAND_DISPLAY="$socket" godot --path "$project" --display-driver wayland --resolution 1600x900 --disable-vsync --max-fps 60 \
	--script res://.claude/skills/verify/driver.gd -- "$scenario" "$evidence" >"$evidence/godot.log" 2>&1 &
godot_pid=$!
# Godot can hang on exit after a scene reload (seen after restart). The driver logs VERIFY DONE before quit,
# so a process alive 15 s after that line is stopped, and the run is judged from the log.
done_for=0
while kill -0 "$godot_pid" 2>/dev/null; do
	if grep -q '^VERIFY DONE' "$evidence/transcript.log" 2>/dev/null; then
		done_for=$((done_for + 1))
		if [[ $done_for -ge 15 ]]; then
			echo "NOTE: Godot did not exit 15 s after VERIFY DONE. Stopped it." | tee -a "$evidence/godot.log"
			kill "$godot_pid" 2>/dev/null || true
			break
		fi
	fi
	sleep 1
done
wait "$godot_pid" || status=$?
godot_pid=""
if grep -q '^NOTE: Godot did not exit' "$evidence/godot.log"; then
	grep -q '^VERIFY DONE failures=0' "$evidence/transcript.log" && status=0 || status=1
fi

grep -E '^(VERIFY|STEP|STATE|PASS|FAIL|REACHED|SHOT|NOTE)|SCRIPT ERROR|ERROR:' "$evidence/godot.log" || true
if [[ $status -ne 0 ]] || grep -qE 'SCRIPT ERROR|^FAIL' "$evidence/godot.log"; then
	echo "RESULT: FAIL (exit $status). Evidence: $evidence"
	exit 1
fi
echo "RESULT: PASS. Evidence: $evidence"
