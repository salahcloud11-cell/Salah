class_name GameManager
extends Node





enum GameState{PLAYING, TRANSITIONING, WRONG, WON}

@export var required_mornings: int = 5
@export_range(0.0, 1.0) var anomaly_chance: float = 0.6
@export var show_debug_info: bool = true

@onready var anomaly_manager: AnomalyManager = $AnomalyManager
@onready var player: PlayerController = $Player
@onready var spawn_point: Node3D = $SpawnPoint
@onready var fade_rect: ColorRect = $CanvasLayer / FadeRect
@onready var morning_label: Label = $CanvasLayer / HUD / MorningLabel
@onready var state_label: Label = $CanvasLayer / HUD / StateLabel
@onready var object_label: Label = $CanvasLayer / HUD / ObjectLabel
@onready var center_label: Label = $CanvasLayer / CenterMessage
@onready var bed: Interactable = $Apartment / Bedroom / Bed
@onready var front_door: Interactable = $Apartment / LivingRoom / FrontDoor

var current_morning: int = 0
var state: GameState = GameState.PLAYING


func _ready() -> void :
	anomaly_manager.anomaly_chance = anomaly_chance
	bed.activated.connect(_on_interactable)
	front_door.activated.connect(_on_interactable)
	center_label.visible = false

	fade_rect.color.a = 1.0
	_start_run()


func _unhandled_input(event: InputEvent) -> void :
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and state == GameState.WON:
			_start_run()


func _start_run() -> void :
	state = GameState.TRANSITIONING
	current_morning = 0
	_begin_morning(1)


func _begin_morning(morning: int) -> void :
	state = GameState.TRANSITIONING
	player.set_input_enabled(false)
	await _fade_to_black()

	anomaly_manager.reset_round()
	player.teleport_to(spawn_point.global_transform)
	current_morning = morning

	if morning == 1:
		anomaly_manager.generate_round(true)
	else:
		anomaly_manager.generate_round()

	_update_hud()

	await _fade_from_black()
	state = GameState.PLAYING
	player.set_input_enabled(true)

	if morning == 1:
		_show_center_message("MONDAY — 06:45 AM\nEverything looks normal...", 2.2)


func _on_interactable(interactable: Interactable) -> void :
	if state != GameState.PLAYING:
		return
	var anomalous: bool = anomaly_manager.is_current_round_anomalous()
	if interactable.decision == Interactable.Decision.LEAVE:
		if anomalous:
			_fail("You left while dreaming.")
		else:
			_advance()
	else:
		if anomalous:
			_advance()
		else:
			_fail("You went back to sleep while awake.")


func _advance() -> void :
	state = GameState.TRANSITIONING
	if current_morning >= required_mornings:
		_win()
		return
	_begin_morning(current_morning + 1)


func _fail(reason: String) -> void :
	state = GameState.WRONG
	player.set_input_enabled(false)
	_show_center_message("WRONG DECISION\n%s" % reason, 2.0)
	await get_tree().create_timer(1.8).timeout
	_start_run()


func _win() -> void :
	state = GameState.WON
	player.set_input_enabled(false)
	center_label.modulate.a = 1.0
	center_label.text = "YOU MADE IT THROUGH THE WEEK\n\nPrototype Complete\n\nPress R to Restart"
	center_label.visible = true


func _fade_to_black() -> void :
	var tw: = create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, 0.4)
	await tw.finished


func _fade_from_black() -> void :
	var tw: = create_tween()
	tw.tween_property(fade_rect, "color:a", 0.0, 0.6)
	await tw.finished


func _show_center_message(text: String, duration: float) -> void :
	center_label.text = text
	center_label.modulate.a = 1.0
	center_label.visible = true
	var tw: = create_tween()
	tw.tween_interval(duration)
	tw.tween_property(center_label, "modulate:a", 0.0, 0.4)
	await tw.finished
	center_label.visible = false


func _update_hud() -> void :
	morning_label.text = "Morning: %d / %d" % [current_morning, required_mornings]
	if show_debug_info:
		state_label.visible = true
		object_label.visible = true
		var anomalous: bool = anomaly_manager.is_current_round_anomalous()
		state_label.text = "State: %s" % ("ANOMALY" if anomalous else "NORMAL")
		var obj_name: String = "---"
		if anomaly_manager.selected_object != null:
			obj_name = anomaly_manager.selected_object.name
		var variant_name: String = "---"
		if anomalous:
			variant_name = anomaly_manager.selected_variant_name
		object_label.text = "Object: %s   Variant: %s" % [obj_name, variant_name]
	else:
		state_label.visible = false
		object_label.visible = false
