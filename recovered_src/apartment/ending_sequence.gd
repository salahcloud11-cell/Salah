extends Node3D




const ENDING_TEXT: = "المفروض انك صحيت، لقد فزت"
const END_VOID_SHADER: = "res://shaders/void_gradient.gdshader"


const DOOR_OPEN_ANGLE: = 100.0
const DOOR_OPEN_SEC: = 1.1
const DOOR_OPEN_STEPS: = 24


const FADE_IN_SEC: = 0.7
const DOOR_BEAT_SEC: = 0.6
const VOID_FADE_SEC: = 0.5
const VOID_DRIFT_SEC: = 6.0
const TEXT_DELAY_SEC: = 0.4
const TEXT_FADE_SEC: = 0.8
const ENDING_HOLD_SEC: = 5.0
const FINAL_FADE_SEC: = 0.9

var _fade_rect: ColorRect
var _door_model: Node3D

@onready var void_rect: ColorRect = $VoidLayer / VoidRect
@onready var ending_text: Label = $VoidLayer / Text


func _ready() -> void :
	var mat: = ShaderMaterial.new()
	mat.shader = load(END_VOID_SHADER) as Shader
	mat.set("shader_parameter/u_alpha", 0.0)
	mat.set("shader_parameter/u_drift", 0.0)
	void_rect.material = mat


func play_ending(player: PlayerController, fade_rect: ColorRect) -> void :
	_fade_rect = fade_rect
	var root: = get_parent()

	player.set_input_enabled(false)
	$VoidLayer.visible = true
	void_rect.material.set("shader_parameter/u_alpha", 0.0)
	void_rect.material.set("shader_parameter/u_drift", 0.0)
	ending_text.text = ENDING_TEXT
	ending_text.modulate.a = 0.0

	_door_model = root.get_node_or_null("FrontDoorModel") as Node3D


	_fade_rect.color.a = 1.0
	var fade_in: = create_tween()
	fade_in.tween_property(_fade_rect, "color:a", 0.0, FADE_IN_SEC)
	_open_door()
	await get_tree().create_timer(FADE_IN_SEC + DOOR_BEAT_SEC).timeout


	var void_tw: = create_tween().set_parallel(true)
	void_tw.tween_property(void_rect.material, "shader_parameter/u_alpha", 1.0, VOID_FADE_SEC)
	void_tw.tween_property(void_rect.material, "shader_parameter/u_drift", 1.0, VOID_DRIFT_SEC)


	await get_tree().create_timer(VOID_FADE_SEC + TEXT_DELAY_SEC).timeout
	var text_tw: = create_tween()
	text_tw.tween_property(ending_text, "modulate:a", 1.0, TEXT_FADE_SEC)


	await get_tree().create_timer(ENDING_HOLD_SEC).timeout
	var fade_tw: = create_tween()
	fade_tw.tween_property(_fade_rect, "color:a", 1.0, FINAL_FADE_SEC)
	await fade_tw.finished
	$VoidLayer.visible = false




func _open_door() -> void :
	if _door_model == null:
		return
	for i in DOOR_OPEN_STEPS:
		_door_model.rotate_y(deg_to_rad(DOOR_OPEN_ANGLE) / DOOR_OPEN_STEPS)
		await get_tree().create_timer(DOOR_OPEN_SEC / DOOR_OPEN_STEPS).timeout
