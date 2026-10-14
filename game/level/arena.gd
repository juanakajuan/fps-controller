class_name Arena
extends Node3D

const SIZE: float = 40.0
const WALL_HEIGHT: float = 3.0
const PLATFORM_HEIGHT: float = 1.5
const STAIR_RISER: float = 0.3
const STAIR_TREAD: float = 0.4
## Finer than the stair riser, so the bake does not join the stairs into the walkable mesh. Zombies cannot climb steps, so they use the ramp.
const NAV_CELL_HEIGHT: float = 0.1
const NAV_MAX_CLIMB: float = 0.2
const GROUND_COLOR: Color = Color(0.32, 0.3, 0.26)
const WALL_COLOR: Color = Color(0.42, 0.4, 0.42)
const COVER_COLOR: Color = Color(0.55, 0.42, 0.3)
const PLATFORM_COLOR: Color = Color(0.36, 0.42, 0.5)
const LAMP_COLOR: Color = Color(1.0, 0.72, 0.4)
const CRATE_COLOR: Color = Color(0.2, 0.26, 0.36)
const GRID_SHADER: String = """
shader_type spatial;

uniform vec3 base_color : source_color = vec3(0.5);
uniform vec3 line_color : source_color = vec3(0.1);

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
	ALBEDO = mix(base_color, line_color, grid_line(plane, 0.5) * 0.35);
	ROUGHNESS = 0.9;
}
"""

var player_spawn: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 6.0))
var zombie_spawns: Array[Vector3] = [
	Vector3(-17.0, 0.0, -17.0), Vector3(0.0, 0.0, -18.0), Vector3(17.0, 0.0, -17.0), Vector3(18.0, 0.0, 0.0),
	Vector3(17.0, 0.0, 17.0), Vector3(0.0, 0.0, 18.0), Vector3(-17.0, 0.0, 17.0), Vector3(-18.0, 0.0, 0.0),
]
var navigation: NavigationRegion3D = NavigationRegion3D.new()
var stations: Array[Station] = []
var box: MysteryBox = MysteryBox.new()

var _shader: Shader = Shader.new()


## Builds the geometry and bakes the navigation mesh at once, so zombies can path on the first physics tick.
func build() -> void:
	_shader.code = GRID_SHADER
	_build_environment()
	add_child(navigation)
	_box(Vector3(SIZE + 2.0, 1.0, SIZE + 2.0), Vector3(0.0, -0.5, 0.0), GROUND_COLOR)
	var half: float = SIZE * 0.5 + 0.5
	_box(Vector3(SIZE + 2.0, WALL_HEIGHT, 1.0), Vector3(0.0, WALL_HEIGHT * 0.5, -half), WALL_COLOR)
	_box(Vector3(SIZE + 2.0, WALL_HEIGHT, 1.0), Vector3(0.0, WALL_HEIGHT * 0.5, half), WALL_COLOR)
	_box(Vector3(1.0, WALL_HEIGHT, SIZE), Vector3(-half, WALL_HEIGHT * 0.5, 0.0), WALL_COLOR)
	_box(Vector3(1.0, WALL_HEIGHT, SIZE), Vector3(half, WALL_HEIGHT * 0.5, 0.0), WALL_COLOR)
	_box(Vector3(4.0, 1.5, 1.0), Vector3(0.0, 0.75, -4.0), COVER_COLOR)
	_box(Vector3(2.0, 2.0, 2.0), Vector3(8.0, 1.0, 4.0), COVER_COLOR)
	_box(Vector3(2.0, 2.0, 2.0), Vector3(-8.0, 1.0, 6.0), COVER_COLOR)
	_box(Vector3(3.0, 1.2, 1.0), Vector3(12.0, 0.6, -2.0), COVER_COLOR)
	_box(Vector3(1.0, 2.5, 4.0), Vector3(5.0, 1.25, 12.0), COVER_COLOR)
	_box(Vector3(3.0, 2.0, 1.0), Vector3(-13.0, 1.0, 10.0), COVER_COLOR)
	_box(Vector3(2.0, 2.0, 2.0), Vector3(13.0, 1.0, 12.0), COVER_COLOR)
	_build_platform(Vector3(-10.0, 0.0, -10.0))
	for corner: Vector3 in [Vector3(-15.0, 0.0, -15.0), Vector3(15.0, 0.0, -15.0), Vector3(15.0, 0.0, 15.0), Vector3(-15.0, 0.0, 15.0)]:
		_lamp(corner)
	_build_stations()
	_bake()


## Before the bake, so the bake cuts the box crate out of the walkable mesh.
func _build_stations() -> void:
	_place(WallBuy.new(Arsenal.smg(), 1000), Vector3(-8.0, 1.5, -19.95), 0.0)
	_place(WallBuy.new(Arsenal.shotgun(), 1200), Vector3(19.95, 1.5, -8.0), -PI * 0.5)
	_place(WallBuy.new(Arsenal.rifle(), 1500), Vector3(-19.95, 1.5, 8.0), PI * 0.5)
	var crate: StaticBody3D = _box(MysteryBox.CRATE_SIZE, Vector3(10.0, MysteryBox.CRATE_SIZE.y * 0.5, 19.5), CRATE_COLOR, Basis(Vector3.UP, PI))
	crate.add_child(box)
	stations.append(box)


## facing turns the station about Y. At 0 its front faces +Z.
func _place(station: Station, at: Vector3, facing: float) -> void:
	station.transform = Transform3D(Basis(Vector3.UP, facing), at)
	add_child(station)
	stations.append(station)


## A 6 m by 6 m platform with stairs on its +Z side for the player and a ramp on its +X side for everyone.
func _build_platform(center: Vector3) -> void:
	_box(Vector3(6.0, PLATFORM_HEIGHT, 6.0), center + Vector3(0.0, PLATFORM_HEIGHT * 0.5, 0.0), PLATFORM_COLOR)
	var steps: int = roundi(PLATFORM_HEIGHT / STAIR_RISER) - 1
	for step: int in range(steps):
		var height: float = STAIR_RISER * (step + 1)
		var z: float = center.z + 3.0 + STAIR_TREAD * (steps - step - 0.5)
		_box(Vector3(3.0, height, STAIR_TREAD), Vector3(center.x, height * 0.5, z), PLATFORM_COLOR)
	var run: float = 5.0
	var slope: float = atan(PLATFORM_HEIGHT / run)
	var length: float = sqrt(run * run + PLATFORM_HEIGHT * PLATFORM_HEIGHT)
	var thickness: float = 0.4
	var middle: Vector3 = center + Vector3(3.0 + run * 0.5, PLATFORM_HEIGHT * 0.5, 0.0)
	var tilt: Basis = Basis(Vector3.BACK, -slope)
	_box(Vector3(length, thickness, 4.0), middle - tilt.y * thickness * 0.5, PLATFORM_COLOR, tilt)


func _bake() -> void:
	NavigationServer3D.map_set_cell_height(get_world_3d().navigation_map, NAV_CELL_HEIGHT)
	var mesh: NavigationMesh = NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = Layers.WORLD
	mesh.cell_height = NAV_CELL_HEIGHT
	mesh.agent_radius = 0.5
	mesh.agent_height = Zombie.HEIGHT
	mesh.agent_max_climb = NAV_MAX_CLIMB
	mesh.agent_max_slope = 30.0
	navigation.navigation_mesh = mesh
	navigation.bake_navigation_mesh(false)
	if mesh.get_polygon_count() == 0:
		push_error("Arena: the navigation bake gave an empty mesh. Zombies cannot find a path.")


func _build_environment() -> void:
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.08, 0.1, 0.2)
	sky_material.sky_horizon_color = Color(0.45, 0.3, 0.3)
	sky_material.ground_horizon_color = Color(0.2, 0.16, 0.16)
	sky_material.ground_bottom_color = Color(0.05, 0.05, 0.06)
	var sky: Sky = Sky.new()
	sky.sky_material = sky_material
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.7
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.3, 0.26, 0.3)
	environment.fog_density = 0.012
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-40.0, 30.0, 0.0)
	moon.light_color = Color(0.7, 0.75, 1.0)
	moon.light_energy = 0.8
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 60.0
	add_child(moon)


func _lamp(at: Vector3) -> void:
	_box(Vector3(0.2, 3.5, 0.2), at + Vector3(0.0, 1.75, 0.0), WALL_COLOR)
	var bulb_material: StandardMaterial3D = StandardMaterial3D.new()
	bulb_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bulb_material.albedo_color = LAMP_COLOR
	var bulb_mesh: BoxMesh = BoxMesh.new()
	bulb_mesh.size = Vector3(0.4, 0.25, 0.4)
	var bulb: MeshInstance3D = MeshInstance3D.new()
	bulb.mesh = bulb_mesh
	bulb.material_override = bulb_material
	bulb.position = at + Vector3(0.0, 3.6, 0.0)
	add_child(bulb)
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = LAMP_COLOR
	light.light_energy = 2.0
	light.omni_range = 14.0
	light.position = at + Vector3(0.0, 3.3, 0.0)
	add_child(light)


func _box(size: Vector3, center: Vector3, color: Color, basis: Basis = Basis.IDENTITY) -> StaticBody3D:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter("base_color", color)
	material.set_shader_parameter("line_color", color.darkened(0.6))
	var view: MeshInstance3D = MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = material
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.transform = Transform3D(basis, center)
	body.add_child(collision)
	body.add_child(view)
	navigation.add_child(body)
	return body
