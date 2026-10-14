class_name Game
extends Node3D

## Of this many random spawn points, the zombie uses the one farthest from the player, so it does not appear in view at close range.
const SPAWN_CANDIDATES: int = 4

var arena: Arena = Arena.new()
var player: Player = Player.new()
var weapon: Weapon = Weapon.new()
var hud: Hud = Hud.new()
var zombies: Node3D = Node3D.new()
var director: RoundDirector = RoundDirector.new()
var points: Points = Points.new()

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	# Game keeps reading the pause and restart actions while the tree is paused. The world below it pauses.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_actions()
	for world: Node in [arena, player, zombies]:
		world.process_mode = Node.PROCESS_MODE_PAUSABLE
	arena.name = "Arena"
	add_child(arena)
	arena.build()
	player.name = "Player"
	add_child(player)
	player.teleport(arena.player_spawn.origin, arena.player_spawn.basis.get_euler().y)
	weapon.def = WeaponDef.starting_pistol()
	player.camera.add_child(weapon)
	zombies.name = "Zombies"
	add_child(zombies)
	add_child(hud)
	weapon.hit.connect(_on_weapon_hit)
	weapon.ammo_changed.connect(hud.set_ammo)
	player.health_changed.connect(hud.set_health)
	player.died.connect(director.player_died)
	points.changed.connect(hud.set_points)
	director.round_started.connect(_on_round_started)
	director.round_cleared.connect(func(_number: int) -> void: hud.show_banner("Round cleared"))
	director.game_over.connect(_on_game_over)
	hud.set_points(points.balance)
	hud.set_ammo(weapon.magazine, weapon.reserve)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	if player.player_controlled:
		weapon.trigger_held = Input.is_action_pressed(&"fire")
		if Input.is_action_just_pressed(&"reload"):
			weapon.reload_requested = true
	elif not player.alive:
		weapon.trigger_held = false
	for spawn: int in range(director.tick(delta)):
		_spawn_zombie()


func _unhandled_input(event: InputEvent) -> void:
	if director.phase == RoundDirector.Phase.GAME_OVER:
		if event.is_action_pressed(&"restart"):
			restart()
		return
	if event.is_action_pressed(&"pause"):
		set_paused(not get_tree().paused)
	elif event is InputEventMouseButton and not get_tree().paused and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func set_paused(paused: bool) -> void:
	get_tree().paused = paused
	hud.set_paused(paused)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED


func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _spawn_zombie() -> void:
	var at: Vector3 = arena.zombie_spawns[_rng.randi_range(0, arena.zombie_spawns.size() - 1)]
	for candidate: int in range(SPAWN_CANDIDATES - 1):
		var other: Vector3 = arena.zombie_spawns[_rng.randi_range(0, arena.zombie_spawns.size() - 1)]
		if other.distance_squared_to(player.global_position) > at.distance_squared_to(player.global_position):
			at = other
	var round_number: int = director.round_number
	var zombie: Zombie = Zombie.new()
	zombie.setup(Rules.zombie_health(round_number), Rules.zombie_speed(round_number, _rng.randf()), player)
	zombie.position = at
	zombie.attacked.connect(player.take_damage)
	zombie.died.connect(func(_headshot: bool) -> void: director.zombie_died())
	zombies.add_child(zombie)


## A zombie can die and free in the same tick as a second ray, so the target is checked.
func _on_weapon_hit(target: Zombie, damage: float, kind: Rules.HitKind) -> void:
	if not is_instance_valid(target) or target.state == Zombie.State.DEAD:
		return
	target.take_damage(damage, kind == Rules.HitKind.HEAD)
	var killed: bool = target.state == Zombie.State.DEAD
	points.earn(Rules.points_for_hit(killed, kind))
	hud.show_hit(killed)


func _on_round_started(round_number: int) -> void:
	weapon.refill()
	hud.set_round(round_number)
	hud.show_banner("Round %d" % round_number)


func _on_game_over(rounds_survived: int) -> void:
	hud.show_death(rounds_survived, points.earned)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _register_actions() -> void:
	_add_action(&"fire", [_mouse(MOUSE_BUTTON_LEFT), _joy_axis(JOY_AXIS_TRIGGER_RIGHT)])
	_add_action(&"reload", [_key(KEY_R), _joy_button(JOY_BUTTON_X)])
	_add_action(&"pause", [_key(KEY_ESCAPE), _joy_button(JOY_BUTTON_START)])
	_add_action(&"restart", [_key(KEY_ENTER), _key(KEY_KP_ENTER), _joy_button(JOY_BUTTON_START)])


static func _add_action(action: StringName, events: Array[InputEvent]) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for event: InputEvent in events:
		InputMap.action_add_event(action, event)


static func _key(code: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	return event


static func _mouse(button: MouseButton) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	return event


static func _joy_button(button: JoyButton) -> InputEventJoypadButton:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.device = -1
	event.button_index = button
	return event


static func _joy_axis(axis: JoyAxis) -> InputEventJoypadMotion:
	var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	event.device = -1
	event.axis = axis
	event.axis_value = 1.0
	return event
