extends Node3D

const SPAWN: Vector3 = Vector3(0.0, 0.0, 8.0)
const GRID_SHADER: String = """
shader_type spatial;

uniform vec3 base_color : source_color = vec3(0.55, 0.57, 0.6);
uniform vec3 line_color : source_color = vec3(0.12, 0.13, 0.15);

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

float grid_line(vec2 coordinate, float width) {
	vec2 cell = abs(fract(coordinate - 0.5) - 0.5) / fwidth(coordinate);
	return 1.0 - clamp(min(cell.x, cell.y) - width, 0.0, 1.0);
}

void fragment() {
	vec3 axis = abs(world_normal);
	vec2 plane = axis.y > max(axis.x, axis.z) ? world_position.xz : (axis.x > axis.z ? world_position.zy : world_position.xy);
	float minor = grid_line(plane, 0.5);
	float major = grid_line(plane / 5.0, 1.0);
	ALBEDO = mix(base_color, line_color, max(minor * 0.45, major));
	ROUGHNESS = 0.85;
}
"""

const FLOOR_COLOR: Color = Color(0.55, 0.57, 0.6)
const STAIR_COLOR: Color = Color(0.85, 0.62, 0.35)
const RAMP_COLOR: Color = Color(0.45, 0.7, 0.55)
const BLOCK_COLOR: Color = Color(0.8, 0.35, 0.32)
const PLATFORM_COLOR: Color = Color(0.4, 0.55, 0.85)
const BOX_COLOR: Color = Color(0.75, 0.72, 0.6)
const GHOST_COLOR: Color = Color(0.4, 0.8, 1.0, 0.35)

var player: FPSController
var ghost: FPSController
var last_recording: FPSRecording
var _shader: Shader = Shader.new()
var _hud: Label


func _ready() -> void:
	_shader.code = GRID_SHADER
	_build_environment()
	_build_level()
	player = FPSController.new()
	player.name = "Player"
	add_child(player)
	player.teleport(SPAWN, 0.0)
	_build_ghost()
	_build_hud()


func _process(_delta: float) -> void:
	_hud.text = "%.1f m/s   %s   %s   %d FPS" % [
		player.horizontal_speed(),
		str(FPSController.MoveState.find_key(player.move_state)),
		str(FPSController.Stance.find_key(player.stance)),
		Engine.get_frames_per_second(),
	]
	if player.is_recording():
		_hud.text += "   REC"
	if ghost.is_playing():
		_hud.text += "   GHOST"


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_R:
		if player.is_recording():
			last_recording = player.stop_recording()
		else:
			player.start_recording()
	elif key.physical_keycode == KEY_G and last_recording != null:
		ghost.visible = true
		ghost.play(last_recording)


func _physics_process(_delta: float) -> void:
	if player.global_position.y < -30.0:
		player.teleport(SPAWN, 0.0)


## The ghost is on no collision layer and ignores the player, so the player walks through it and it cannot push the player off the recorded path.
func _build_ghost() -> void:
	ghost = FPSController.new()
	ghost.name = "Ghost"
	ghost.player_controlled = false
	ghost.collision_layer = 0
	ghost.add_collision_exception_with(player)
	ghost.visible = false
	add_child(ghost)
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = ghost.settings.capsule_radius
	capsule.height = ghost.settings.stand_height
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = GHOST_COLOR
	var view: MeshInstance3D = MeshInstance3D.new()
	view.mesh = capsule
	view.material_override = material
	view.position = Vector3(0.0, capsule.height * 0.5, 0.0)
	ghost.add_child(view)


func _build_environment() -> void:
	var sky: Sky = Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)


func _build_level() -> void:
	_box(Vector3(240.0, 1.0, 240.0), Vector3(0.0, -0.5, 0.0), FLOOR_COLOR)
	_stairs(-18.0, 0.2, 0.4, 8, "Stairs 0.2 m")
	_stairs(-12.0, 0.35, 0.45, 5, "Stairs 0.35 m")
	_box(Vector3(3.0, 0.6, 3.0), Vector3(-6.0, 0.3, -4.5), BLOCK_COLOR)
	_sign("0.6 m step: too tall", Vector3(-6.0, 1.6, -3.0))
	_box(Vector3(4.0, 0.3, 10.0), Vector3(0.0, 1.45, -26.0), BLOCK_COLOR)
	_box(Vector3(0.5, 1.6, 10.0), Vector3(-2.25, 0.8, -26.0), BLOCK_COLOR)
	_box(Vector3(0.5, 1.6, 10.0), Vector3(2.25, 0.8, -26.0), BLOCK_COLOR)
	_sign("Tunnel 1.3 m: crouch or slide", Vector3(0.0, 2.4, -20.5))
	_sign("Sprint, then crouch to slide", Vector3(0.0, 2.2, -6.0))
	_ramp(6.0, 20.0, "Ramp 20°")
	_ramp(12.0, 35.0, "Ramp 35°")
	_ramp(18.0, 55.0, "Slope 55°: too steep")
	_platforms(26.0)
	_box(Vector3(1.0, 1.0, 1.0), Vector3(-4.0, 0.5, 6.0), BOX_COLOR)
	_box(Vector3(1.5, 1.5, 1.5), Vector3(-6.5, 0.75, 8.0), BOX_COLOR)
	_box(Vector3(0.5, 0.5, 0.5), Vector3(-3.0, 0.25, 9.0), BOX_COLOR)
	_box(Vector3(2.0, 0.8, 1.0), Vector3(4.0, 0.4, 7.0), BOX_COLOR, Basis(Vector3.UP, 0.4))


func _stairs(x: float, riser: float, tread: float, count: int, label: String) -> void:
	for step: int in range(count):
		var height: float = riser * (step + 1)
		_box(Vector3(3.0, height, tread), Vector3(x, height * 0.5, -3.0 - tread * (step + 0.5)), STAIR_COLOR)
	var top: float = riser * count
	_box(Vector3(3.0, top, 4.0), Vector3(x, top * 0.5, -5.0 - tread * count), STAIR_COLOR)
	_sign(label, Vector3(x, 1.2, -1.5))


func _ramp(x: float, degrees: float, label: String) -> void:
	var slope: float = deg_to_rad(degrees)
	var length: float = 8.0
	var thickness: float = 0.5
	var center: Vector3 = Vector3(
		x,
		length * 0.5 * sin(slope) - thickness * 0.5 * cos(slope),
		-3.0 - length * 0.5 * cos(slope) - thickness * 0.5 * sin(slope))
	_box(Vector3(4.0, thickness, length), center, RAMP_COLOR, Basis(Vector3.RIGHT, slope))
	var top: float = length * sin(slope)
	_box(Vector3(4.0, top, 4.0), Vector3(x, top * 0.5, -5.0 - length * cos(slope)), RAMP_COLOR)
	_sign(label, Vector3(x, 1.2, -1.5))


func _platforms(x: float) -> void:
	var z: float = -3.0
	for gap: float in [0.0, 2.5, 4.0, 5.5]:
		z -= gap
		_box(Vector3(3.0, 1.0, 3.0), Vector3(x, 0.5, z - 1.5), PLATFORM_COLOR)
		if gap > 0.0:
			_sign("%.1f m gap" % gap, Vector3(x, 2.2, z + gap * 0.5))
		z -= 3.0
	_sign("Jump gaps", Vector3(x, 1.8, -1.5))


func _box(size: Vector3, center: Vector3, color: Color, basis: Basis = Basis.IDENTITY) -> void:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter("base_color", color)
	var view: MeshInstance3D = MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = material
	var body: StaticBody3D = StaticBody3D.new()
	body.transform = Transform3D(basis, center)
	body.add_child(collision)
	body.add_child(view)
	add_child(body)


func _sign(text: String, at: Vector3) -> void:
	var label: Label3D = Label3D.new()
	label.text = text
	label.position = at
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.outline_size = 12
	label.pixel_size = 0.004
	add_child(label)


func _build_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var panel: VBoxContainer = VBoxContainer.new()
	panel.position = Vector2(16.0, 12.0)
	layer.add_child(panel)
	_hud = _hud_label(22)
	panel.add_child(_hud)
	var controls: Label = _hud_label(15)
	controls.text = "WASD move   Space jump   Shift sprint   Ctrl or C crouch   R start or stop recording   G play the recording on a ghost   Esc free mouse   Click capture mouse"
	panel.add_child(controls)


func _hud_label(size: int) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	return label
