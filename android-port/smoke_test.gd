extends SceneTree
## Headless smoke test for the Android port (run by android-qa.yml).
## Loads the menu, presses Start, skips the intro, walks the player,
## checks camera look and the dream scene, then reports SMOKE PASS/FAIL.

var failures: Array[String] = []


func _ok(msg: String) -> void:
	print("SMOKE-OK: ", msg)


func _fail(msg: String) -> void:
	failures.append(msg)
	printerr("SMOKE-FAIL: ", msg)


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


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


func _run() -> void:
	await _wait(1.0)
	var names := []
	for c in root.get_children():
		names.append(c.name)
	_ok("root children (autoloads): %s" % [names])
	if root.get_node_or_null("TouchControls") == null:
		_fail("TouchControls autoload missing")
	if root.get_node_or_null("Settings") == null:
		_fail("Settings autoload missing")

	# 1) main menu
	var err := change_scene_to_file("res://ui/MainMenu.tscn")
	if err != OK:
		_fail("change_scene_to_file(MainMenu) err=%d" % err)
	await _wait(2.0)
	if current_scene == null:
		_fail("no current scene after menu load")
		_finish()
		return
	_ok("menu scene: %s" % current_scene.name)
	var start_btn := current_scene.get_node_or_null("MenuWrap/MenuContainer/StartButton") as Button
	if start_btn == null:
		_fail("StartButton not found in menu")
		_finish()
		return

	# 2) press Start -> apartment scene
	start_btn.pressed.emit()
	var waited := 0.0
	while waited < 15.0:
		await _wait(0.5)
		waited += 0.5
		if current_scene != null and current_scene.name != "MainMenu":
			break
	if current_scene == null or current_scene.name == "MainMenu":
		_fail("game scene did not load after Start (scene=%s)" % (current_scene.name if current_scene else "null"))
		_finish()
		return
	_ok("game scene: %s" % current_scene.name)

	var player := _find_player(current_scene)
	if player == null:
		_fail("player not found in game scene")
		_finish()
		return
	_ok("player found")

	# 3) skip intro (Escape), wait for gameplay input
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

	# 4) look: mouse motion should change target yaw
	var yaw_before: float = player.get("target_yaw")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(240, 0)
	Input.parse_input_event(motion)
	await _wait(0.5)
	var yaw_after: float = player.get("target_yaw")
	if not is_equal_approx(yaw_before, yaw_after):
		_ok("camera look works (yaw %.3f -> %.3f)" % [yaw_before, yaw_after])
	else:
		_fail("camera look did not respond to mouse motion")

	# 5) walk forward
	var pos_before: Vector3 = player.global_position
	Input.action_press("up")
	await _wait(1.6)
	Input.action_release("up")
	await _wait(0.3)
	var moved: float = (player.global_position - pos_before).length()
	if moved > 0.4:
		_ok("player walked %.2f m" % moved)
	else:
		_fail("player did not move (moved %.3f m)" % moved)

	# 6) dream scene integrity (character models etc.)
	var dream_ps := load("res://dreams/DreamCorridor.tscn") as PackedScene
	if dream_ps == null:
		_fail("DreamCorridor.tscn failed to load")
	else:
		var dream := dream_ps.instantiate()
		root.add_child(dream)
		await _wait(1.5)
		_ok("DreamCorridor instantiated")
		dream.queue_free()
		await _wait(0.5)

	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("SMOKE PASS")
		quit(0)
	else:
		printerr("SMOKE FAILED (%d): %s" % [failures.size(), failures])
		print("SMOKE FAIL")
		quit(1)
