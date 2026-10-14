#!/usr/bin/env bash
# Runs every headless check. The visual smoke needs a display, so it is not here.
set -euo pipefail
cd "$(dirname "$0")/.."

fail_on_output() {
	local label="$1"
	shift
	local output
	if ! output="$("$@" 2>&1)" || grep -qE 'ERROR|WARNING' <<<"$output"; then
		echo "$output"
		echo "FAIL: $label"
		exit 1
	fi
	echo "OK: $label"
}

run_suite() {
	local engine="$1"
	local output
	local status=0
	output="$(godot --headless --path . -s tests/test_runner.gd 2>&1)" || status=$?
	echo "Test suite on $engine:"
	grep -E 'RESULT|FAIL|SCRIPT ERROR' <<<"$output" || true
	if [[ $status -ne 0 ]] || ! grep -q 'RESULT: [0-9]* checks, 0 failures' <<<"$output"; then
		echo "FAIL: test suite on $engine"
		exit 1
	fi
}

if [[ -e override.cfg ]]; then
	echo "override.cfg exists. Move it away, then run the checks again."
	exit 1
fi

fail_on_output "editor import" godot --headless --path . --editor --quit
for script in $(find game tests -name '*.gd' | sort); do
	fail_on_output "parse $script" godot --headless --path . --check-only -s "$script"
done

run_suite "Jolt Physics"

trap 'rm -f override.cfg' EXIT
printf '[physics]\n\n3d/physics_engine="GodotPhysics3D"\n' >override.cfg
run_suite "Godot Physics"
rm -f override.cfg

fail_on_output "launch the game for 600 frames" godot --headless --path . --quit-after 600
