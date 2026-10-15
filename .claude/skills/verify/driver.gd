extends SceneTree
## Plays the real main scene from a scenario file. It sends real input events and writes state, logs, and screenshots.
## Usage: godot --path . --script res://.claude/skills/verify/driver.gd -- <scenario-file> <evidence-dir>

const MAIN_SCENE: String = "res://game/main.tscn"
## nearest_zombie_m when no zombie is alive, so a wait for "<= N" does not pass early.
const NO_ZOMBIE_DISTANCE: float = 999.0
const PHASES: PackedStringArray = ["STARTING", "ACTIVE", "INTERMISSION", "GAME_OVER"]
const WEAPON_STATES: PackedStringArray = ["READY", "COOLDOWN", "RELOADING", "MELEE", "SWITCHING"]
const MOVE_STATES: PackedStringArray = ["GROUND", "AIR", "SLIDE"]
const STANCES: PackedStringArray = ["STAND", "CROUCH"]
const BOX_PHASES: PackedStringArray = ["IDLE", "ROLLING", "OFFERING"]
## walk_to stops this close to its target.
const ARRIVE_DISTANCE: float = 0.3
const BURST_TICKS: int = 12

var _evidence: String = ""
var _log: FileAccess
var _failures: int = 0
var _held_keys: Array[Key] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: -- <scenario-file> <evidence-dir>")
		quit(2)
		return
	_evidence = args[1]
	DirAccess.make_dir_recursive_absolute(_evidence)
	_log = FileAccess.open(_evidence.path_join("transcript.log"), FileAccess.WRITE)
	var scenario: FileAccess = FileAccess.open(args[0], FileAccess.READ)
	if scenario == null:
		_fail("cannot open scenario %s" % args[0])
		quit(2)
		return
	var game: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	await process_frame
	_say("VERIFY READY scenario=%s evidence=%s" % [args[0], _evidence])
	var line_number: int = 0
	while not scenario.eof_reached():
		var line: String = scenario.get_line().strip_edges()
		line_number += 1
		if line.is_empty() or line.begins_with("#"):
			continue
		_say("STEP %d: %s" % [line_number, line])
		var ok: bool = await _step(line)
		if not ok:
			_fail("step %d failed: %s" % [line_number, line])
			break
	for key: Key in _held_keys.duplicate():
		_key(key, false)
	_say("VERIFY DONE failures=%d" % _failures)
	_log.close()
	quit(0 if _failures == 0 else 1)


func _step(line: String) -> bool:
	var words: PackedStringArray = line.split(" ", false)
	var command: String = words[0]
	var rest: PackedStringArray = words.slice(1)
	match command:
		"wait":
			await create_timer(float(rest[0])).timeout
		"press":
			return _key_by_name(rest[0], true)
		"release":
			return _key_by_name(rest[0], false)
		"tap":
			if not _key_by_name(rest[0], true):
				return false
			await physics_frame
			await physics_frame
			_key_by_name(rest[0], false)
		"mouse_down":
			_mouse_button(true)
		"mouse_up":
			_mouse_button(false)
		"click":
			_mouse_button(true)
			await physics_frame
			await physics_frame
			_mouse_button(false)
		"look":
			_look(Vector2(float(rest[0]), float(rest[1])))
		"aim_nearest":
			var aimed: bool = _aim_nearest(rest[0] if rest.size() > 0 else "body")
			await _settle_view()
			return aimed
		"walk_to":
			return await _walk_to(Vector2(float(rest[0]), float(rest[1])), float(rest[2]))
		"face":
			_face(deg_to_rad(float(rest[0])), deg_to_rad(float(rest[1])) if rest.size() > 1 else 0.0)
			await _settle_view()
		"fight":
			await _fight(float(rest[0]), rest[1] if rest.size() > 1 else "head")
		"shot":
			await _screenshot(rest[0])
		"state":
			_say("STATE " + JSON.stringify(_state()))
		"expect":
			# The value keeps its inner spaces, as in the prompt "E  Buy SMG  1000".
			var parts: PackedStringArray = line.split(" ", false, 3)
			return _expect(parts[1], parts[2], parts[3] if parts.size() > 3 else "")
		"wait_until":
			return await _wait_until(rest[0], rest[1], rest[2], float(rest[3]))
		_:
			_say("FAIL unknown command %s" % command)
			return false
	return true


func _game() -> Game:
	return current_scene as Game


## Every field that expect and wait_until can read. The values come from the live nodes, not from the test hooks.
func _state() -> Dictionary:
	var game: Game = _game()
	var nearest: Zombie = _nearest_zombie()
	var live: int = 0
	for child: Node in game.zombies.get_children():
		if (child as Zombie).state != Zombie.State.DEAD:
			live += 1
	return {
		"phase": PHASES[game.director.phase],
		"round": game.director.round_number,
		"to_spawn": game.director.to_spawn,
		"zombies_alive": live,
		"nearest_zombie_m": snappedf(game.player.global_position.distance_to(nearest.global_position), 0.01) if nearest != null else NO_ZOMBIE_DISTANCE,
		"points": game.points.balance,
		"earned": game.points.earned,
		"magazine": game.weapon.current().magazine,
		"reserve": game.weapon.current().reserve,
		"weapon": WEAPON_STATES[game.weapon.state],
		"weapon_name": game.weapon.current().def.display_name,
		"slots": _slots(game.weapon.loadout),
		"box": BOX_PHASES[game.arena.box.phase],
		"health": snappedf(game.player.health, 0.1),
		"player_alive": game.player.alive,
		"move_state": MOVE_STATES[game.player.move_state],
		"stance": STANCES[game.player.stance],
		"speed": snappedf(game.player.horizontal_speed(), 0.01),
		"position": "%.2f,%.2f,%.2f" % [game.player.global_position.x, game.player.global_position.y, game.player.global_position.z],
		"yaw_deg": snappedf(rad_to_deg(game.player.yaw), 0.1),
		"paused": paused,
		"fps": Engine.get_frames_per_second(),
		"ticks_ms": Time.get_ticks_msec(),
		"mouse_captured": Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,
		"hud_round": game.hud.round_label.text,
		"hud_points": game.hud.points_label.text,
		"hud_ammo": game.hud.ammo_label.text,
		"hud_weapon": game.hud.weapon_label.text,
		"hud_prompt": game.hud.prompt_label.text if game.hud.prompt_label.visible else "",
		"hud_banner": game.hud.banner.text if game.hud.banner.modulate.a > 0.0 else "",
		"hud_death": game.hud.death_screen.visible,
		"hud_death_text": game.hud.death_text.text if game.hud.death_screen.visible else "",
		"hud_pause": game.hud.pause_screen.visible,
	}


func _expect(field: String, op: String, wanted: String) -> bool:
	var state: Dictionary = _state()
	if not state.has(field):
		_say("FAIL unknown field %s" % field)
		return false
	var ok: bool = _compare(state[field], op, wanted)
	_say("%s %s %s %s (actual %s)" % ["PASS" if ok else "FAIL", field, op, wanted, str(state[field])])
	return ok


func _wait_until(field: String, op: String, wanted: String, timeout: float) -> bool:
	var deadline: float = Time.get_ticks_msec() / 1000.0 + timeout
	while Time.get_ticks_msec() / 1000.0 < deadline:
		var state: Dictionary = _state()
		if state.has(field) and _compare(state[field], op, wanted):
			_say("REACHED %s %s %s" % [field, op, wanted])
			return true
		await physics_frame
	_say("FAIL timeout after %.1f s: %s %s %s (last %s)" % [timeout, field, op, wanted, str(_state().get(field))])
	return false


func _compare(actual: Variant, op: String, wanted: String) -> bool:
	if actual is String:
		var text: String = actual
		match op:
			"==": return text == wanted
			"!=": return text != wanted
			"contains": return text.contains(wanted)
		return false
	if actual is bool:
		var flag: bool = actual
		var wanted_flag: bool = wanted == "true"
		return flag == wanted_flag if op == "==" else flag != wanted_flag
	var number: float = float(str(actual))
	var target: float = float(wanted)
	match op:
		"==": return is_equal_approx(number, target)
		"!=": return not is_equal_approx(number, target)
		">": return number > target
		"<": return number < target
		">=": return number >= target
		"<=": return number <= target
	return false


func _key_by_name(name: String, pressed: bool) -> bool:
	var key: Key = OS.find_keycode_from_string(name)
	if key == KEY_NONE:
		_say("FAIL unknown key %s" % name)
		return false
	_key(key, pressed)
	return true


func _key(key: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	if pressed and not _held_keys.has(key):
		_held_keys.append(key)
	elif not pressed:
		_held_keys.erase(key)


func _mouse_button(pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = root.get_visible_rect().size * 0.5
	Input.parse_input_event(event)


func _look(pixels: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.relative = pixels
	event.screen_relative = pixels
	Input.parse_input_event(event)


## Turns the view with mouse motion, the same path as a real mouse. Part "head" aims at the head, "body" at the chest.
func _aim_nearest(part: String) -> bool:
	var target: Zombie = _nearest_zombie()
	if target == null:
		_say("FAIL no live zombie to aim at")
		return false
	var player: Player = _game().player
	var height: float = Rules.ZOMBIE_HEAD_HEIGHT + 0.15 if part == "head" else 1.0
	var offset: Vector3 = target.global_position + Vector3.UP * height - player.camera.global_position
	var want_yaw: float = atan2(-offset.x, -offset.z)
	var want_pitch: float = atan2(offset.y, Vector2(offset.x, offset.z).length())
	var turn: float = deg_to_rad(player.mouse_sensitivity)
	var delta_yaw: float = wrapf(want_yaw - player.yaw, -PI, PI)
	var delta_pitch: float = want_pitch - player.pitch
	_look(Vector2(-delta_yaw / turn, -delta_pitch / turn))
	return true


## Turns the view to a yaw and a pitch with one mouse motion. Yaw 0 faces -Z, and yaw 90 faces -X.
func _face(yaw: float, pitch: float) -> void:
	var player: Player = _game().player
	var turn: float = deg_to_rad(player.mouse_sensitivity)
	_look(Vector2(-wrapf(yaw - player.yaw, -PI, PI) / turn, -(pitch - player.pitch) / turn))


## Holds W and steers with mouse motion until the player is within ARRIVE_DISTANCE of the point on the floor.
func _walk_to(target: Vector2, timeout: float) -> bool:
	var player: Player = _game().player
	var deadline: float = Time.get_ticks_msec() / 1000.0 + timeout
	_key(KEY_W, true)
	var arrived: bool = false
	while Time.get_ticks_msec() / 1000.0 < deadline:
		var offset: Vector2 = target - Vector2(player.global_position.x, player.global_position.z)
		if offset.length() < ARRIVE_DISTANCE:
			arrived = true
			break
		_face(atan2(-offset.x, -offset.y), player.pitch)
		await physics_frame
	_key(KEY_W, false)
	if not arrived:
		_say("FAIL walk_to %.1f %.1f timed out at %.2f,%.2f" % [target.x, target.y, player.global_position.x, player.global_position.z])
	return arrived


func _slots(loadout: Loadout) -> String:
	var names: PackedStringArray = []
	for index: int in range(loadout.slots.size()):
		names.append(("*" if index == loadout.active else "") + loadout.slots[index].def.display_name)
	return ",".join(names)


## Aims at the nearest zombie and holds the fire button for BURST_TICKS, again and again, until the time ends or the round is cleared.
## A semi-automatic weapon fires once for each hold, and an automatic weapon fires a burst.
func _fight(seconds: float, part: String) -> void:
	var deadline: float = Time.get_ticks_msec() / 1000.0 + seconds
	while Time.get_ticks_msec() / 1000.0 < deadline and _game().director.phase == RoundDirector.Phase.ACTIVE:
		if _nearest_zombie() != null:
			_aim_nearest(part)
			await _settle_view()
			_mouse_button(true)
			for tick: int in range(BURST_TICKS):
				await physics_frame
			_mouse_button(false)
		await create_timer(0.3).timeout


## The camera rig applies a look on the next rendered frame. A shot or knife in the same physics tick uses the old view.
func _settle_view() -> void:
	await process_frame
	await physics_frame
	await process_frame


func _nearest_zombie() -> Zombie:
	var game: Game = _game()
	var best: Zombie = null
	var best_distance: float = INF
	for child: Node in game.zombies.get_children():
		var zombie: Zombie = child as Zombie
		if zombie.state == Zombie.State.DEAD:
			continue
		var distance: float = zombie.global_position.distance_to(game.player.global_position)
		if distance < best_distance:
			best = zombie
			best_distance = distance
	return best


func _screenshot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = _evidence.path_join(name + ".png")
	var result: Error = root.get_texture().get_image().save_png(path)
	_say("SHOT %s %s" % [path, error_string(result)])


func _say(text: String) -> void:
	print(text)
	_log.store_line(text)
	_log.flush()


func _fail(text: String) -> void:
	_failures += 1
	push_error(text)
	if _log != null:
		_say("FAIL " + text)
