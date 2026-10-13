## Records the test route into the golden file. Run it again after a change that is meant to change movement, then update the literal end position in test_golden_run().
## godot --headless --path . -s tests/record_golden.gd
extends "res://tests/test_runner.gd"


func _initialize() -> void:
	call_deferred("record")


func record() -> void:
	var run: Run = await record_route()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GOLDEN_PATH.get_base_dir()))
	var saved: Error = ResourceSaver.save(run.recording, GOLDEN_PATH)
	print("Saved %s with %d ticks: %s" % [GOLDEN_PATH, run.recording.tick_count(), error_string(saved)])
	var copy: Run = await replay(load(GOLDEN_PATH) as FPSRecording)
	print("Recorded end %s. Played end %s." % [str(run.end), str(copy.end)])
	print("Events: %s" % str(run.events))
	quit(0 if saved == OK else 1)
