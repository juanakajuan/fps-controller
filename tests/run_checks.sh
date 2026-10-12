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

if [[ -e override.cfg ]]; then
	echo "override.cfg exists. Move it away, then run the checks again."
	exit 1
fi

fail_on_output "editor import" godot --headless --path . --editor --quit
for script in addons/fps_controller/*.gd demo/*.gd tests/*.gd; do
	fail_on_output "parse $script" godot --headless --path . --check-only -s "$script"
done

echo "Test suite on Jolt Physics:"
godot --headless --path . -s tests/test_runner.gd 2>&1 | grep -E 'RESULT|FAIL|SCRIPT ERROR'

trap 'rm -f override.cfg' EXIT
printf '[physics]\n\n3d/physics_engine="GodotPhysics3D"\n' >override.cfg
echo "Test suite on Godot Physics:"
godot --headless --path . -s tests/test_runner.gd 2>&1 | grep -E 'RESULT|FAIL|SCRIPT ERROR'
rm -f override.cfg

fail_on_output "launch the demo for 180 frames" godot --headless --path . --quit-after 180
