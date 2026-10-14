class_name Hud
extends CanvasLayer

const HIT_MARKER_SECONDS: float = 0.15
const BANNER_SECONDS: float = 3.0
const ROUND_COLOR: Color = Color(0.75, 0.08, 0.06)
const TEXT_COLOR: Color = Color(0.95, 0.93, 0.88)
const KILL_COLOR: Color = Color(1.0, 0.2, 0.15)
const VIGNETTE_COLOR: Color = Color(0.6, 0.0, 0.0)
const PROMPT_GRAY: Color = Color(0.55, 0.55, 0.55)

var round_label: Label = _label(64, ROUND_COLOR)
var points_label: Label = _label(30, TEXT_COLOR)
var ammo_label: Label = _label(34, TEXT_COLOR)
var weapon_label: Label = _label(24, TEXT_COLOR)
var prompt_label: Label = _label(28, TEXT_COLOR)
var banner: Label = _label(56, TEXT_COLOR)
var death_screen: Control = Control.new()
var death_text: Label = _label(28, TEXT_COLOR)
var pause_screen: Control = Control.new()

var _vignette: TextureRect = TextureRect.new()
var _hit_marker: Control
var _hit_parts: Array[ColorRect] = []
var _hit_left: float = 0.0
var _banner_left: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_vignette()
	_build_crosshair()
	_build_hit_marker()
	round_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_KEEP_SIZE, 32)
	round_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(round_label)
	points_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_KEEP_SIZE, 32)
	add_child(points_label)
	var weapon_box: VBoxContainer = VBoxContainer.new()
	weapon_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_KEEP_SIZE, 32)
	weapon_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	weapon_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	weapon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(weapon_box)
	for label: Label in [weapon_label, ammo_label]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		weapon_box.add_child(label)
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	prompt_label.offset_top = 48.0
	prompt_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(prompt_label)
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	banner.offset_top = 160.0
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.modulate.a = 0.0
	add_child(banner)
	_build_overlay(death_screen, Color(0.05, 0.0, 0.0, 0.75), "YOU DIED", death_text)
	var resume_hint: Label = _label(24, TEXT_COLOR)
	resume_hint.text = "Esc  resume\n\nWASD  move     Space  jump     Shift  sprint     Ctrl or C  crouch, slide\nLeft mouse  fire     R  reload     V  knife\nE  buy     Q or mouse wheel  change weapon"
	_build_overlay(pause_screen, Color(0.0, 0.0, 0.0, 0.6), "PAUSED", resume_hint)
	set_round(0)
	set_points(0)
	set_ammo(0, 0)
	set_weapon("")
	set_prompt("", true)
	set_health(Rules.PLAYER_MAX_HEALTH)


func _process(delta: float) -> void:
	_hit_left -= delta
	_hit_marker.visible = _hit_left > 0.0
	_banner_left -= delta
	banner.modulate.a = clampf(_banner_left, 0.0, 1.0)


func set_round(round_number: int) -> void:
	round_label.text = str(round_number) if round_number > 0 else ""


func set_points(balance: int) -> void:
	points_label.text = "%d" % balance


func set_ammo(magazine: int, reserve: int) -> void:
	ammo_label.text = "%d / %d" % [magazine, reserve]


func set_weapon(weapon_name: String) -> void:
	weapon_label.text = weapon_name


## "" hides the prompt. A prompt that the player cannot pay for is gray.
func set_prompt(text: String, affordable: bool) -> void:
	prompt_label.text = text
	prompt_label.visible = text != ""
	prompt_label.modulate = Color.WHITE if affordable else PROMPT_GRAY


func set_health(health: float) -> void:
	_vignette.modulate.a = 1.0 - health / Rules.PLAYER_MAX_HEALTH


func show_hit(killed: bool) -> void:
	_hit_left = HIT_MARKER_SECONDS
	for part: ColorRect in _hit_parts:
		part.color = KILL_COLOR if killed else TEXT_COLOR


func show_banner(text: String) -> void:
	banner.text = text
	_banner_left = BANNER_SECONDS


func show_death(rounds_survived: int, points_earned: int) -> void:
	death_text.text = "You survived %d %s.\nYou earned %d points.\n\nPress Enter to play again." % [rounds_survived, "round" if rounds_survived == 1 else "rounds", points_earned]
	death_screen.visible = true


func set_paused(paused: bool) -> void:
	pause_screen.visible = paused


func _build_vignette() -> void:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(VIGNETTE_COLOR, 0.0))
	gradient.set_color(1, Color(VIGNETTE_COLOR, 0.85))
	gradient.set_offset(0, 0.45)
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 1.0)
	_vignette.texture = texture
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_vignette)


func _build_crosshair() -> void:
	var center: Control = _centered()
	for offset: Vector2 in [Vector2(-12.0, -1.0), Vector2(5.0, -1.0)]:
		_bar(center, Rect2(offset, Vector2(7.0, 2.0)), TEXT_COLOR)
	for offset: Vector2 in [Vector2(-1.0, -12.0), Vector2(-1.0, 5.0)]:
		_bar(center, Rect2(offset, Vector2(2.0, 7.0)), TEXT_COLOR)


func _build_hit_marker() -> void:
	_hit_marker = _centered()
	_hit_marker.visible = false
	for angle: float in [45.0, 135.0, 225.0, 315.0]:
		var arm: Control = Control.new()
		arm.rotation_degrees = angle
		_hit_marker.add_child(arm)
		_hit_parts.append(_bar(arm, Rect2(Vector2(8.0, -1.5), Vector2(9.0, 3.0)), TEXT_COLOR))


func _build_overlay(screen: Control, shade: Color, title: String, body: Label) -> void:
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.visible = false
	add_child(screen)
	var background: ColorRect = ColorRect.new()
	background.color = shade
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(background)
	var column: VBoxContainer = VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 24)
	screen.add_child(column)
	var heading: Label = _label(72, ROUND_COLOR)
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(body)


func _centered() -> Control:
	var center: Control = Control.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	return center


func _bar(parent: Control, rect: Rect2, color: Color) -> ColorRect:
	var bar: ColorRect = ColorRect.new()
	bar.position = rect.position
	bar.size = rect.size
	bar.color = color
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar)
	return bar


static func _label(size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
