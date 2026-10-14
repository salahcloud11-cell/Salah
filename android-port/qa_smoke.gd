extends Node
## QaSmoke — temporary autoload injected ONLY by android-qa.yml.
## Runs inside the real game (normal main loop, autoloads active):
## menu -> Start -> skip intro -> look -> walk -> dream/character checks.
## Prints SMOKE PASS/FAIL and quits with a matching exit code. Never shipped.

var failures: Array[String] = []


func _ok(msg: String) -> void:
	print("SMOKE-OK: ", msg)


func _fail(msg: String) -> void:
	failures.append(msg)
	printerr("SMOKE-FAIL: ", msg)


func _ready() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _send_key(keycode: Key) -> void:
	var press := InputEventKey.new()
	press.keycode = keycode
	press.physical_keycode = keycode
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventKey.new()
	release.keycode = keycode
	release.physical_keycode = keycode
	release.pressed = false
	Input.parse_input_event(release)


func _send_joy_motion(axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = -1
	ev.axis = axis
	ev.axis_value = value
	Input.parse_input_event(ev)


func _find_player(node: Node) -> Node:
	if node == null:
		return null
	if node is PlayerController:
		return node
	for child in node.get_children():
		var found := _find_player(child)
		if found != null:
			return found
	return null


func _dump_tree(node: Node, depth: int, max_depth: int) -> void:
	var pad := ""
	for i in depth:
		pad += "  "
	print("TREE: ", pad, node.name, " (", node.get_class(), ")")
	if depth >= max_depth:
		return
	for child in node.get_children():
		_dump_tree(child, depth + 1, max_depth)


func _run() -> void:
	await _wait(1.5)
	_ok("scene at boot: %s" % (get_tree().current_scene.name if get_tree().current_scene else "null"))
	if get_node_or_null("/root/TouchControls") == null:
		_fail("TouchControls autoload missing")
	if get_node_or_null("/root/Settings") == null:
		_fail("Settings autoload missing")


	var renderer := str(ProjectSettings.get_setting("rendering/renderer/rendering_method", ""))
	if renderer == "glcompatibility":
		_ok("lite renderer active: glcompatibility (32-bit/low-end build)")
	else:
		_fail("expected glcompatibility renderer, got: %s" % renderer)

	var base_w := int(ProjectSettings.get_setting("display/window/size/viewport_width", 0))
	if base_w == 1152:
		_ok("UI base resolution 1152x648 (normal text size, no zoom)")
	else:
		_fail("UI base width changed: %d" % base_w)
	var shadow_lights := 0
	for cls in ["OmniLight3D", "SpotLight3D", "DirectionalLight3D"]:
		for n in get_tree().current_scene.find_children("*", cls, true, false):
			if (n as Light3D).shadow_enabled:
				shadow_lights += 1
	if shadow_lights == 0:
		_ok("all light shadows disabled (low-end)")
	else:
		_fail("%d lights still cast shadows" % shadow_lights)

	# v5 lowest-end (1.5 GB RAM class) settings
	if bool(ProjectSettings.get_setting("rendering/shading/overrides/force_vertex_shading", false)):
		_ok("vertex shading forced (cheap lighting for weak GPUs)")
	else:
		_fail("force_vertex_shading not enabled")
	var render_scale := float(ProjectSettings.get_setting("rendering/scaling_3d/scale", 1.0))
	if render_scale <= 0.45:
		_ok("3D base render scale %.2f (1.5 GB class)" % render_scale)
	else:
		_fail("3D base render scale too high: %.2f" % render_scale)
	var aniso := int(ProjectSettings.get_setting("rendering/textures/default_filters/anisotropic_filtering_level", 0))
	if aniso <= 1:
		_ok("anisotropic filtering low/off (%d)" % aniso)
	else:
		_fail("anisotropy too high: %d" % aniso)
	var phys_tps := int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 60))
	if phys_tps <= 30:
		_ok("physics ticks %d/s matched to 30 FPS cap" % phys_tps)
	else:
		_fail("physics ticks too high: %d" % phys_tps)

	var start_btn := get_tree().current_scene.get_node_or_null("MenuWrap/MenuContainer/StartButton") as Button
	if start_btn == null:
		_fail("StartButton not found")
		_finish()
		return
	start_btn.pressed.emit()
	var waited := 0.0
	while waited < 15.0:
		await _wait(0.5)
		waited += 0.5
		if get_tree().current_scene != null and get_tree().current_scene.name != "MainMenu":
			break
	if get_tree().current_scene == null or get_tree().current_scene.name == "MainMenu":
		_fail("game scene did not load after Start")
		_finish()
		return
	_ok("game scene: %s" % get_tree().current_scene.name)
	var scene := get_tree().current_scene

	if scene.get_node_or_null("Bedroom/Furniture/Bed") == null:
		_fail("Bed interactable missing")
	else:
		_ok("Bed interactable present")
	if scene.get_node_or_null("FrontDoor") == null:
		_fail("FrontDoor interactable missing")
	else:
		_ok("FrontDoor interactable present")

	var player := _find_player(scene)
	if player == null:
		_fail("player not found")
		_finish()
		return
	_ok("player found")

	for i in 3:
		_send_key(KEY_ESCAPE)
		await _wait(1.0)
	waited = 0.0
	while waited < 25.0:
		if player.get("input_enabled"):
			break
		_send_key(KEY_ESCAPE)
		await _wait(1.0)
		waited += 1.0
	if player.get("input_enabled"):
		_ok("gameplay input enabled after intro skip")
	else:
		_fail("player input never enabled (intro stuck?)")

	var yaw_before: float = player.get("target_yaw")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(240, 0)
	Input.parse_input_event(motion)
	await _wait(0.5)
	var yaw_after: float = player.get("target_yaw")
	if not is_equal_approx(yaw_before, yaw_after):
		_ok("camera look works (yaw %.3f -> %.3f)" % [yaw_before, yaw_after])
	else:
		_fail("camera look did not respond")

	var pos_before: Vector3 = player.global_position
	Input.action_press("up")
	await _wait(1.6)
	Input.action_release("up")
	await _wait(0.3)
	var moved: float = (player.global_position - pos_before).length()
	if moved > 0.4:
		_ok("player walked %.2f m" % moved)
	else:
		_fail("player did not move (%.3f m)" % moved)


	# 7) gamepad: bindings exist for every gameplay action
	for action in ["up", "down", "left", "right", "jump", "sprint", "interact"]:
		var has_pad := false
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				has_pad = true
		if has_pad:
			_ok("gamepad binding present: %s" % action)
		else:
			_fail("gamepad binding MISSING: %s" % action)

	# 8) gamepad: right stick turns the camera (via TouchControls pad look)
	var pad_yaw_before: float = player.get("target_yaw")
	_send_joy_motion(JOY_AXIS_RIGHT_X, 1.0)
	await _wait(0.8)
	_send_joy_motion(JOY_AXIS_RIGHT_X, 0.0)
	await _wait(0.2)
	var pad_yaw_after: float = player.get("target_yaw")
	if absf(pad_yaw_after - pad_yaw_before) > 0.3:
		_ok("right stick look works (yaw %.3f -> %.3f)" % [pad_yaw_before, pad_yaw_after])
	else:
		_fail("right stick look did not turn camera")

	# 9) gamepad: left stick drives the 'up' action with analog strength
	_send_joy_motion(JOY_AXIS_LEFT_Y, -1.0)
	await _wait(0.4)
	var stick_vec := Input.get_vector("left", "right", "up", "down")
	_send_joy_motion(JOY_AXIS_LEFT_Y, 0.0)
	if stick_vec.y < -0.5:
		_ok("left stick movement works (vector %s)" % stick_vec)
	else:
		_fail("left stick did not drive movement actions (%s)" % stick_vec)

	# character models (redirected FBX->GLB)
	for path in ["res://apartment/assets/characters/character_male.tscn", "res://apartment/assets/characters/character_female.tscn"]:
		var ps := load(path) as PackedScene
		if ps == null:
			_fail("%s failed to load" % path)
			continue
		var inst := ps.instantiate()
		add_child(inst)
		await _wait(0.5)
		var skel: Skeleton3D = null
		for n in inst.find_children("*", "Skeleton3D", true, false):
			skel = n as Skeleton3D
			break
		if skel != null:
			_ok("%s has Skeleton3D (%d bones)" % [path.get_file(), skel.get_bone_count()])
		else:
			_fail("%s: NO Skeleton3D under model" % path.get_file())
			_dump_tree(inst, 0, 4)
		inst.queue_free()
		await _wait(0.3)

	var dream_ps := load("res://dreams/DreamCorridor.tscn") as PackedScene
	if dream_ps == null:
		_fail("DreamCorridor.tscn failed to load")
	else:
		var dream := dream_ps.instantiate()
		get_tree().root.add_child(dream)
		await _wait(1.5)
		_ok("DreamCorridor instantiated")
		dream.queue_free()
		await _wait(0.5)

	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("SMOKE PASS")
		get_tree().quit(0)
	else:
		printerr("SMOKE FAILED (%d): %s" % [failures.size(), failures])
		print("SMOKE FAIL")
		get_tree().quit(1)
