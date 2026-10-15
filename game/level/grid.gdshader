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
