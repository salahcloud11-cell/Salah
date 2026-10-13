extends Node3D





var test_mode: bool = false

@onready var anomaly_manager: AnomalyManager = $AnomalyManager
@onready var player: PlayerController = $Player
@onready var test_button: Button = $CanvasLayer / TestModeButton
@onready var debug_label: Label = $CanvasLayer / DebugLabel


func _ready() -> void :
	test_button.pressed.connect(_toggle_test_mode)
	_update_test_ui()


func _toggle_test_mode() -> void :
	test_mode = not test_mode
	player.set_input_enabled( not test_mode)
	if test_mode:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_update_test_ui()


func _unhandled_input(event: InputEvent) -> void :
	if not test_mode:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_G:
				anomaly_manager.generate_round()
			KEY_R:
				anomaly_manager.reset_round()
			KEY_M:
				_toggle_test_mode()


func _process(_delta: float) -> void :
	if test_mode:
		_update_debug_label()


func _update_test_ui() -> void :
	test_button.text = "TEST MODE: ON" if test_mode else "TEST MODE: OFF"
	debug_label.visible = test_mode


func _update_debug_label() -> void :
	var obj_name: String = "---"
	if anomaly_manager.selected_object != null:
		obj_name = anomaly_manager.selected_object.name
	var variant_name: String = "---"
	if anomaly_manager.has_anomaly:
		variant_name = anomaly_manager.selected_variant_name
	var state: String = "ANOMALY" if anomaly_manager.has_anomaly else "NORMAL"
	debug_label.text = "State: %s\nObject: %s\nVariant: %s\nG = New round   R = Reset"\
	%[state, obj_name, variant_name]
