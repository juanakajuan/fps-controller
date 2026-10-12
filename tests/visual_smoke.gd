extends SceneTree

const DEMO: PackedScene = preload("res://demo/demo.tscn")
const DEFAULT_OUTPUT: String = "user://visual_smoke.png"


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var output: String = ProjectSettings.globalize_path(args[0] if args.size() > 0 else DEFAULT_OUTPUT)
	var demo: Node = DEMO.instantiate()
	root.add_child(demo)
	current_scene = demo
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await create_timer(3.0).timeout
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var spread: float = luminance_spread(image)
	var result: Error = image.save_png(output)
	print("VISUAL SMOKE: %dx%d image, luminance spread %.3f, save %s, %s" % [image.get_width(), image.get_height(), spread, error_string(result), output])
	var blank: bool = spread < 0.1
	if blank:
		push_error("FAIL: the captured frame is blank")
	quit(0 if result == OK and not blank else 1)


func luminance_spread(image: Image) -> float:
	var darkest: float = 1.0
	var brightest: float = 0.0
	for y: int in range(0, image.get_height(), 16):
		for x: int in range(0, image.get_width(), 16):
			var luminance: float = image.get_pixel(x, y).get_luminance()
			darkest = minf(darkest, luminance)
			brightest = maxf(brightest, luminance)
	return brightest - darkest
