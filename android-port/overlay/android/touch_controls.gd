extends CanvasLayer
## TouchControls — Android controls overlay for "Awake or Not?" (مستيقظ أم لا؟)
##
## Added as an autoload by the Android port; the original game code is
## untouched. It provides:
##   * a virtual joystick (bottom-left) that drives the existing
##     "left"/"right"/"up"/"down" input actions (analog strength),
##   * INTERACT / JUMP / SPRINT buttons (bottom-right) that drive the
##     existing "interact"/"jump"/"sprint" actions,
##   * camera look by dragging on the screen (Godot's touch->mouse
##     emulation: the player rotates on InputEventMouseMotion),
##   * NEXT / SKIP during cutscenes, sending Space / Escape keys,
##   * PS3 / generic gamepad support: left stick + D-pad move and the
##     right stick looks around (pad bindings for the game actions are
##     injected into project.godot by android-port/patch_project.py;
##     DualShock 3 mapping: ✕ jump, ▢/△ interact, L3/L1 sprint,
##     Start = skip/menu-back (Escape), ✕ in cutscenes = next line).
##     When a gamepad is being used the touch UI hides itself,
##   * adaptive render resolution on Android: the 3D render scale is
##     lowered/raised in steps to hold a playable frame rate on
##     low-end GPUs; Q-/Q+ buttons (top-right) adjust it manually.

const JOY_RADIUS := 64.0
const JOY_DEADZONE := 0.12
const PAD_DEADZONE := 0.18
const PAD_LOOK_YAW_SPEED := 2.8
const PAD_LOOK_PITCH_SPEED := 2.1
const SCALE_STEPS: Array[float] = [0.6, 0.5, 0.4, 0.33, 0.25]

var _is_touch := false
var _on_android := false
var _player: PlayerController = null
var _scan_cooldown := 0.0
var _disabled_time := 0.0

var _game_ui: Control
var _cine_ui: Control
var _joy_base: Control
var _joy_knob: Control
var _joy_index := -1
var _joy_mouse := false
var _joy_was_active := false
var _interact_btn: Button
var _sprint_btn: Button
var _quality_ui: Control
var _quality_lbl: Label

# --- gamepad state ---
var _pad_mode := false
var _pad_look := Vector2.ZERO

# --- adaptive resolution state ---
var _scale_idx := 2
var _fps_timer := 0.0
var _low_windows := 0
var _high_windows := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_on_android = OS.get_name() == "Android" or OS.has_feature("android")
	_is_touch = DisplayServer.is_touchscreen_available() or _on_android
	_pad_mode = not Input.get_connected_joypads().is_empty()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_build_ui()
	_game_ui.visible = false
	_cine_ui.visible = false
	if _on_android:
		_apply_render_scale()


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		_pad_mode = true
	elif Input.get_connected_joypads().is_empty():
		_pad_mode = false
		_pad_look = Vector2.ZERO


func _build_ui() -> void:
	# ---------- in-game controls ----------
	_game_ui = Control.new()
	_game_ui.name = "GameUI"
	_game_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_game_ui)

	# virtual joystick (bottom-left)
	_joy_base = Control.new()
	_joy_base.name = "Joystick"
	_joy_base.anchor_top = 1.0
	_joy_base.anchor_bottom = 1.0
	_joy_base.offset_left = 44.0
	_joy_base.offset_top = -244.0
	_joy_base.offset_right = 244.0
	_joy_base.offset_bottom = -44.0
	_joy_base.mouse_filter = Control.MOUSE_FILTER_STOP
	_game_ui.add_child(_joy_base)

	var base_circle := Panel.new()
	base_circle.set_anchors_preset(Control.PRESET_FULL_RECT)
	base_circle.add_theme_stylebox_override("panel", _circle_style(Color(1, 1, 1, 0.10), Color(1, 1, 1, 0.45), 100))
	base_circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joy_base.add_child(base_circle)

	_joy_knob = Panel.new()
	_joy_knob.size = Vector2(76, 76)
	_joy_knob.position = Vector2(62, 62)
	_joy_knob.add_theme_stylebox_override("panel", _circle_style(Color(1, 1, 1, 0.30), Color(1, 1, 1, 0.65), 38))
	_joy_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joy_base.add_child(_joy_knob)
	_joy_base.gui_input.connect(_on_joy_gui_input)

	# action buttons (bottom-right)
	_interact_btn = _make_button("تفاعل\nUSE", 104, Color(1.0, 0.85, 0.35, 1.0))
	_interact_btn.anchor_left = 1.0
	_interact_btn.anchor_right = 1.0
	_interact_btn.anchor_top = 1.0
	_interact_btn.anchor_bottom = 1.0
	_interact_btn.offset_left = -140.0
	_interact_btn.offset_right = -36.0
	_interact_btn.offset_top = -290.0
	_interact_btn.offset_bottom = -186.0
	_game_ui.add_child(_interact_btn)
	_interact_btn.button_down.connect(func() -> void: Input.action_press("interact"))
	_interact_btn.button_up.connect(func() -> void: Input.action_release("interact"))

	var jump_btn := _make_button("قفز\nJUMP", 84, Color(1, 1, 1, 1))
	jump_btn.anchor_left = 1.0
	jump_btn.anchor_right = 1.0
	jump_btn.anchor_top = 1.0
	jump_btn.anchor_bottom = 1.0
	jump_btn.offset_left = -248.0
	jump_btn.offset_right = -164.0
	jump_btn.offset_top = -164.0
	jump_btn.offset_bottom = -80.0
	_game_ui.add_child(jump_btn)
	jump_btn.button_down.connect(func() -> void: Input.action_press("jump"))
	jump_btn.button_up.connect(func() -> void: Input.action_release("jump"))

	_sprint_btn = _make_button("ركض\nRUN", 84, Color(1, 1, 1, 1))
	_sprint_btn.toggle_mode = true
	_sprint_btn.anchor_left = 1.0
	_sprint_btn.anchor_right = 1.0
	_sprint_btn.anchor_top = 1.0
	_sprint_btn.anchor_bottom = 1.0
	_sprint_btn.offset_left = -124.0
	_sprint_btn.offset_right = -40.0
	_sprint_btn.offset_top = -164.0
	_sprint_btn.offset_bottom = -80.0
	_game_ui.add_child(_sprint_btn)
	_sprint_btn.toggled.connect(_on_sprint_toggled)

	# look hint
	var hint := Label.new()
	hint.text = "اسحب يمين الشاشة للنظر حولك"
	hint.anchor_left = 0.5
	hint.anchor_right = 0.5
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = -200.0
	hint.offset_right = 200.0
	hint.offset_top = -56.0
	hint.offset_bottom = -30.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game_ui.add_child(hint)

	# ---------- quality (3D resolution) quick controls ----------
	_quality_ui = Control.new()
	_quality_ui.name = "QualityUI"
	_quality_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_quality_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_quality_ui)

	_quality_lbl = Label.new()
	_quality_lbl.text = "3D 40%"
	_quality_lbl.anchor_left = 1.0
	_quality_lbl.anchor_right = 1.0
	_quality_lbl.offset_left = -238.0
	_quality_lbl.offset_right = -156.0
	_quality_lbl.offset_top = 30.0
	_quality_lbl.offset_bottom = 58.0
	_quality_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_quality_lbl.add_theme_font_size_override("font_size", 17)
	_quality_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	_quality_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quality_ui.add_child(_quality_lbl)

	var q_minus := _make_button("Q-", 56, Color(1, 1, 1, 1))
	q_minus.anchor_left = 1.0
	q_minus.anchor_right = 1.0
	q_minus.offset_left = -148.0
	q_minus.offset_right = -84.0
	q_minus.offset_top = 16.0
	q_minus.offset_bottom = 72.0
	_quality_ui.add_child(q_minus)
	q_minus.pressed.connect(func() -> void: _step_quality(1))

	var q_plus := _make_button("Q+", 56, Color(1, 1, 1, 1))
	q_plus.anchor_left = 1.0
	q_plus.anchor_right = 1.0
	q_plus.offset_left = -76.0
	q_plus.offset_right = -12.0
	q_plus.offset_top = 16.0
	q_plus.offset_bottom = 72.0
	_quality_ui.add_child(q_plus)
	q_plus.pressed.connect(func() -> void: _step_quality(-1))

	# ---------- cutscene controls ----------
	_cine_ui = Control.new()
	_cine_ui.name = "CineUI"
	_cine_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cine_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cine_ui)

	var tap := Button.new()
	tap.set_anchors_preset(Control.PRESET_FULL_RECT)
	tap.focus_mode = Control.FOCUS_NONE
	tap.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	tap.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	tap.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	_cine_ui.add_child(tap)
	tap.pressed.connect(func() -> void: _send_key(KEY_SPACE))

	var skip_btn := _make_button("تخطي SKIP ≫", 72, Color(1, 1, 1, 1))
	skip_btn.anchor_left = 1.0
	skip_btn.anchor_right = 1.0
	skip_btn.anchor_top = 1.0
	skip_btn.anchor_bottom = 1.0
	skip_btn.offset_left = -210.0
	skip_btn.offset_right = -30.0
	skip_btn.offset_top = -110.0
	skip_btn.offset_bottom = -38.0
	_cine_ui.add_child(skip_btn)
	skip_btn.pressed.connect(func() -> void: _send_key(KEY_ESCAPE))

	var next_lbl := Label.new()
	next_lbl.text = "اضغط في أي مكان للمتابعة"
	next_lbl.anchor_left = 0.5
	next_lbl.anchor_right = 0.5
	next_lbl.anchor_top = 1.0
	next_lbl.anchor_bottom = 1.0
	next_lbl.offset_left = -220.0
	next_lbl.offset_right = 220.0
	next_lbl.offset_top = -52.0
	next_lbl.offset_bottom = -24.0
	next_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_lbl.add_theme_font_size_override("font_size", 20)
	next_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	next_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cine_ui.add_child(next_lbl)


func _circle_style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	return sb


func _make_button(text: String, _size_px: int, tint: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 21)
	b.add_theme_color_override("font_color", tint)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0.38)
	normal.border_color = Color(1, 1, 1, 0.55)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(18)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(1, 1, 1, 0.35)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


# Track which device the player is actually using + capture pad look.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_pad_mode = false
	elif event is InputEventJoypadButton:
		var btn := event as InputEventJoypadButton
		if btn.pressed:
			_pad_mode = true
			if btn.button_index == JOY_BUTTON_START or btn.button_index == JOY_BUTTON_BACK:
				_send_key(KEY_ESCAPE)
			elif btn.button_index == JOY_BUTTON_A and _player != null and not _player.input_enabled:
				# cutscene/dialogue: Cross = next line
				_send_key(KEY_SPACE)
	elif event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if motion.axis == JOY_AXIS_RIGHT_X:
			_pad_look.x = motion.axis_value
			if absf(motion.axis_value) > 0.25:
				_pad_mode = true
		elif motion.axis == JOY_AXIS_RIGHT_Y:
			_pad_look.y = motion.axis_value
			if absf(motion.axis_value) > 0.25:
				_pad_mode = true
		elif absf(motion.axis_value) > 0.3:
			_pad_mode = true


func _process(delta: float) -> void:
	if not _is_touch and not _pad_mode:
		return
	_scan_cooldown -= delta
	if not is_instance_valid(_player):
		_player = null
	if _player == null and _scan_cooldown <= 0.0:
		_scan_cooldown = 0.4
		_player = _find_player(get_tree().current_scene)

	var in_game := _player != null and _player.input_enabled
	if in_game:
		_disabled_time = 0.0
		_apply_pad_look(delta)
	else:
		_disabled_time += delta

	var show_touch := _is_touch and not _pad_mode
	if _game_ui.visible != (in_game and show_touch):
		_game_ui.visible = in_game and show_touch
		if not _game_ui.visible:
			_release_all_actions()
	# cutscene UI only after input has been disabled a moment
	# (avoids flashing during short day-transition fades)
	var show_cine := _player != null and not in_game and _disabled_time > 2.0 and show_touch
	if _cine_ui.visible != show_cine:
		_cine_ui.visible = show_cine
	# quality buttons ride along with whichever control set is visible
	if is_instance_valid(_quality_ui):
		_quality_ui.visible = _game_ui.visible or _cine_ui.visible

	# highlight USE when an interactable is in reach
	if _player != null and is_instance_valid(_interact_btn):
		if _player.current_interactable != null:
			_interact_btn.modulate = Color(1.3, 1.15, 0.6)
		else:
			_interact_btn.modulate = Color.WHITE

	if _on_android and _player != null:
		_update_adaptive_resolution(delta)


func _apply_pad_look(delta: float) -> void:
	if _player == null:
		return
	var look := _pad_look
	for device in Input.get_connected_joypads():
		var v := Vector2(
			Input.get_joy_axis(device, JOY_AXIS_RIGHT_X),
			Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y))
		if v.length() > look.length():
			look = v
	if look.length() < PAD_DEADZONE:
		return
	var mag := clampf((look.length() - PAD_DEADZONE) / (1.0 - PAD_DEADZONE), 0.0, 1.0)
	var vec := look.normalized() * mag
	var sens_factor := clampf(_player.sensitivity / 0.004, 0.25, 5.0)
	_player.target_yaw -= vec.x * PAD_LOOK_YAW_SPEED * sens_factor * delta
	_player.target_pitch = clampf(
		_player.target_pitch - vec.y * PAD_LOOK_PITCH_SPEED * sens_factor * delta,
		deg_to_rad(-60.0), deg_to_rad(60.0))


# --- low-end support: dynamic render resolution --------------------
func _apply_render_scale() -> void:
	# Only scale the 3D render buffer. The window/content scale is left
	# at the game's design size (1152x648) so UI text keeps its normal
	# size and the image is not zoomed (v3 bug).
	var vp := get_viewport()
	if vp != null:
		vp.scaling_3d_scale = SCALE_STEPS[_scale_idx]
	if is_instance_valid(_quality_lbl):
		_quality_lbl.text = "3D %d%%" % int(round(SCALE_STEPS[_scale_idx] * 100.0))


func _step_quality(dir: int) -> void:
	_scale_idx = clampi(_scale_idx + dir, 0, SCALE_STEPS.size() - 1)
	_low_windows = 0
	_high_windows = 0
	_apply_render_scale()


func _update_adaptive_resolution(delta: float) -> void:
	_fps_timer += delta
	if _fps_timer < 2.0:
		return
	_fps_timer = 0.0
	var fps := Performance.get_monitor(Performance.TIME_FPS)
	if fps < 27.0:
		_low_windows += 1
		_high_windows = 0
		if _low_windows >= 2 and _scale_idx < SCALE_STEPS.size() - 1:
			_scale_idx += 1
			_low_windows = 0
			_apply_render_scale()
	elif fps > 57.0:
		_high_windows += 1
		_low_windows = 0
		if _high_windows >= 4 and _scale_idx > 0:
			_scale_idx -= 1
			_high_windows = 0
			_apply_render_scale()
	else:
		_low_windows = 0
		_high_windows = 0


func _find_player(node: Node) -> PlayerController:
	if node == null:
		return null
	if node is PlayerController:
		return node as PlayerController
	for child in node.get_children():
		var found := _find_player(child)
		if found != null:
			return found
	return null


func _release_all_actions() -> void:
	# Only release the axes the touch joystick itself was driving, so a
	# gamepad held at the same time is not cancelled out.
	if _joy_was_active:
		for action in ["left", "right", "up", "down"]:
			Input.action_release(action)
	for action in ["interact", "jump"]:
		Input.action_release(action)
	if is_instance_valid(_sprint_btn) and not _sprint_btn.is_pressed():
		Input.action_release("sprint")
	_joy_index = -1
	_joy_mouse = false
	_joy_was_active = false
	if is_instance_valid(_joy_knob):
		_joy_knob.position = Vector2(62, 62)
	if is_instance_valid(_sprint_btn) and _sprint_btn.is_pressed():
		_sprint_btn.set_pressed_no_signal(false)
		Input.action_release("sprint")


func _set_action_strength(action: String, strength: float) -> void:
	if strength > 0.05:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _on_sprint_toggled(on: bool) -> void:
	if on:
		Input.action_press("sprint")
	else:
		Input.action_release("sprint")


func _on_joy_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _joy_index == -1:
			_pad_mode = false
			_joy_index = touch.index
			_joy_update(touch.position)
		elif not touch.pressed and touch.index == _joy_index:
			_joy_index = -1
			_joy_reset()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _joy_index:
			_joy_update(drag.position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_joy_mouse = true
				_joy_update(mb.position)
			else:
				_joy_mouse = false
				_joy_reset()
	elif event is InputEventMouseMotion and _joy_mouse:
		_joy_update((event as InputEventMouseMotion).position)


func _joy_update(local_pos: Vector2) -> void:
	var center := _joy_base.size * 0.5
	var offset := local_pos - center
	if offset.length() > JOY_RADIUS:
		offset = offset.normalized() * JOY_RADIUS
	_joy_knob.position = center + offset - _joy_knob.size * 0.5
	var v := offset / JOY_RADIUS
	if v.length() < JOY_DEADZONE:
		v = Vector2.ZERO
	_joy_was_active = v != Vector2.ZERO
	_set_action_strength("up", clampf(-v.y, 0.0, 1.0))
	_set_action_strength("down", clampf(v.y, 0.0, 1.0))
	_set_action_strength("left", clampf(-v.x, 0.0, 1.0))
	_set_action_strength("right", clampf(v.x, 0.0, 1.0))


func _joy_reset() -> void:
	_joy_knob.position = Vector2(62, 62)
	_joy_was_active = false
	for action in ["up", "down", "left", "right"]:
		Input.action_release(action)


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
