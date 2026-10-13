class_name ApartmentGameManager
extends Node





enum GameState{INTRO, PLAYING, TRANSITIONING, WRONG, WON}


@export var required_days: int = 10
@export_range(0.0, 1.0) var anomaly_chance: float = 0.6


@export_range(0.0, 1.0) var wake_voice_chance: float = 0.7


@export var menu_background_mode: bool = false




@export var difficulty_by_day: Array[int] = [1, 1, 1, 2, 2, 2, 3, 3, 3, 3]

@onready var anomaly_manager: AnomalyManager = $AnomalyManager
@onready var player: PlayerController = $Player
@onready var spawn_point: Node3D = $PlayerSpawn
@onready var fade_rect: ColorRect = $CanvasLayer / FadeRect
@onready var morning_label: Label = $CanvasLayer / HUD / MorningLabel
@onready var center_label: Label = $CanvasLayer / CenterMessage
@onready var bed: Interactable = $Bedroom / Furniture / Bed
@onready var front_door: Interactable = $FrontDoor

var current_day: int = 0
var state: GameState = GameState.PLAYING


const DAY_HIT_PATH: = "res://audio/day_hit.mp3"
const DAY_ENTRY_BLACK_HOLD_SEC: = 1.2
const DAY_ENTRY_HOLD_SEC: = 1.4
const DAY_ENTRY_FADE_SEC: = 0.5
const DAY_ENTRY_POP_SEC: = 0.4
const DAY_ENTRY_POP_START: = 0.7


const WAKE_AUDIO_FILES: = [
	"res://audio/wake/wake_1.mp3", 
	"res://audio/wake/wake_2.mp3", 
	"res://audio/wake/wake_3.mp3", 
	"res://audio/wake/wake_4.mp3", 
	"res://audio/wake/wake_5.mp3", 
	"res://audio/wake/wake_6.mp3", 
	"res://audio/wake/wake_7.mp3", 
]
const WAKE_VOICE_LEVEL_DB: = -4.0


const WAKE_ANIM_SEC: = 1.6
const WAKE_LIE_YAW: = 40.0
const WAKE_LIE_PITCH: = -50.0
const WAKE_LIE_ROLL: = -60.0
const WAKE_LIE_LOWER: = 0.55
const WAKE_LIE_OFFSET_X: = 0.12
const WAKE_LIE_OFFSET_Z: = 0.08

var _day_hit_sfx: AudioStreamPlayer = null
var _wake_streams: Array[AudioStream] = []
var _wake_voice: AudioStreamPlayer = null


const DREAM_1_SCENE: = "res://dreams/DreamCorridor.tscn"
const DREAM_AFTER_DAY_1: = 3
const DREAM_AFTER_DAY_2: = 8
const DREAM_1_WAKE_DAY: = 4
const DREAM_2_WAKE_DAY: = 9
const MAIN_MENU_SCENE: = "res://ui/MainMenu.tscn"

var dream_1_done: bool = false
var dream_2_done: bool = false
var _dream_active: bool = false
var _dream_2_running: bool = false
var _dream_node: Node3D = null
var _dream_rotator: Node3D = null


func _ready() -> void :
	anomaly_manager.anomaly_chance = anomaly_chance
	bed.activated.connect(_on_interactable)
	front_door.activated.connect(_on_interactable)
	center_label.visible = false
	_setup_day_sfx()
	_setup_wake_voice()
	if menu_background_mode:
		_setup_menu_background()
		return
	fade_rect.color.a = 1.0
	state = GameState.INTRO
	await $IntroController.play_intro(player, fade_rect, $CanvasLayer, anomaly_manager)
	_start_run()




func _setup_menu_background() -> void :
	player.set_input_enabled(false)
	player.visible = false
	anomaly_manager.reset_round()
	_hide_hud()
	center_label.visible = false
	fade_rect.color.a = 0.0
	$IntroController / IntroUI.visible = false
	$LossController / RedLayer.visible = false
	if has_node("EndingController"):
		$EndingController / VoidLayer.visible = false
	var shot_cam: = $IntroController / IntroCameras / Shot02_ApartmentWide as Camera3D
	if shot_cam:
		shot_cam.make_current()


func _start_run() -> void :
	state = GameState.TRANSITIONING
	current_day = 0
	dream_1_done = false
	dream_2_done = false
	_dream_active = false
	_dream_2_running = false
	_begin_day(0)


func _begin_day(day: int) -> void :
	state = GameState.TRANSITIONING
	player.set_input_enabled(false)
	await _fade_to_black()

	anomaly_manager.reset_round()
	player.teleport_to(spawn_point.global_transform)
	current_day = day

	if day == 0:
		anomaly_manager.generate_round(true)
	else:
		anomaly_manager.set_difficulty(_difficulty_for_day(day))
		anomaly_manager.generate_round()

	_update_hud()

	await _play_day_entry(day)
	state = GameState.PLAYING
	player.set_input_enabled(true)






func _play_day_entry(day: int) -> void :
	var text: = "اليوم %d | 06:45 صباحا" % day
	if day == 0:
		text += "\nاحفظ شكل الشقة بشكل كامل"
	elif day == 1:
		text += "\nتأكد أن كل شيء نفس السابق وأنك لست في حلم"
	center_label.text = text
	center_label.pivot_offset = center_label.size * 0.5
	center_label.scale = Vector2.ONE * DAY_ENTRY_POP_START
	center_label.modulate.a = 1.0
	center_label.visible = true
	if _day_hit_sfx:
		_day_hit_sfx.play()
	var pop: = create_tween()
	pop.tween_property(center_label, "scale", Vector2.ONE, DAY_ENTRY_POP_SEC)\
	.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_set_wake_pose()
	await get_tree().create_timer(DAY_ENTRY_BLACK_HOLD_SEC).timeout
	await _fade_from_black()
	_play_wake_animation()
	_play_wake_voice()
	await get_tree().create_timer(DAY_ENTRY_HOLD_SEC).timeout
	var tw: = create_tween()
	tw.tween_property(center_label, "modulate:a", 0.0, DAY_ENTRY_FADE_SEC)
	await tw.finished
	center_label.visible = false
	center_label.scale = Vector2.ONE


func _setup_day_sfx() -> void :
	_day_hit_sfx = AudioStreamPlayer.new()
	_day_hit_sfx.name = "DayHitSFX"
	_day_hit_sfx.bus = "SFX"
	_day_hit_sfx.stream = load(DAY_HIT_PATH)
	add_child(_day_hit_sfx)


func _setup_wake_voice() -> void :
	_wake_voice = AudioStreamPlayer.new()
	_wake_voice.name = "WakeVoice"
	_wake_voice.bus = "SFX"
	_wake_voice.volume_db = WAKE_VOICE_LEVEL_DB
	add_child(_wake_voice)
	for path in WAKE_AUDIO_FILES:
		var stream: = load(path) as AudioStream
		if stream:
			_wake_streams.append(stream)



func _play_wake_voice() -> void :
	if _wake_streams.is_empty():
		return
	if randf() >= wake_voice_chance:
		return
	_wake_voice.stream = _wake_streams[randi() % _wake_streams.size()]
	_wake_voice.play()



func _set_wake_pose() -> void :
	var head: Node3D = player.get_node("Head")
	var cam: Camera3D = player.get_node("Head/Camera3D")
	head.rotation.y = deg_to_rad(WAKE_LIE_YAW)
	cam.position = Vector3(WAKE_LIE_OFFSET_X, - WAKE_LIE_LOWER, WAKE_LIE_OFFSET_Z)
	cam.rotation_degrees = Vector3(WAKE_LIE_PITCH, 0.0, WAKE_LIE_ROLL)




func _play_wake_animation() -> void :
	var head: Node3D = player.get_node("Head")
	var cam: Camera3D = player.get_node("Head/Camera3D")
	var tw: = create_tween().set_parallel(true)
	tw.tween_property(head, "rotation:y", 0.0, WAKE_ANIM_SEC)\
	.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cam, "position", Vector3.ZERO, WAKE_ANIM_SEC)\
	.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cam, "rotation_degrees", Vector3.ZERO, WAKE_ANIM_SEC)\
	.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _difficulty_for_day(day: int) -> int:
	if day < 0 or day >= difficulty_by_day.size():
		return AnomalyObject.Difficulty.HARD
	return clampi(difficulty_by_day[day], AnomalyObject.Difficulty.EASY, AnomalyObject.Difficulty.HARD)


func _on_interactable(interactable: Interactable) -> void :
	if _dream_active:
		if _dream_2_running and interactable == bed:
			_end_dream_2()
		return
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
	if current_day >= required_days - 1:
		_run_final_ending()
		return
	if current_day == DREAM_AFTER_DAY_1 and not dream_1_done:
		dream_1_done = true
		_run_dream_interlude_1()
	elif current_day == DREAM_AFTER_DAY_2 and not dream_2_done:
		dream_2_done = true
		_run_dream_interlude_2()
	else:
		_begin_day(current_day + 1)



func _run_final_ending() -> void :
	await $EndingController.play_ending(player, fade_rect)
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)



func _run_dream_interlude_1() -> void :
	_dream_active = true
	player.set_input_enabled(false)
	await _fade_to_black()
	_hide_apartment_world()
	var dream: DreamCorridor = (load(DREAM_1_SCENE) as PackedScene).instantiate()
	add_child(dream)
	_dream_node = dream
	await _fade_from_black()
	await dream.finished
	await _fade_to_black()
	player.get_node("Head/Camera3D").make_current()
	_show_apartment_world()
	_dream_node.queue_free()
	_dream_node = null
	_dream_active = false
	_begin_day(DREAM_1_WAKE_DAY)




func _run_dream_interlude_2() -> void :
	_dream_active = true
	_dream_2_running = true
	player.set_input_enabled(false)
	await _fade_to_black()
	_hide_hud()
	anomaly_manager.reset_round()
	player.teleport_to(spawn_point.global_transform)
	_dream_rotator = load("res://dreams/dream2_rotator.gd").new()
	add_child(_dream_rotator)
	await _fade_from_black()
	await get_tree().create_timer(1.2).timeout
	player.set_input_enabled(true)


func _end_dream_2() -> void :
	if not _dream_2_running:
		return
	_dream_2_running = false
	_dream_active = false
	player.set_input_enabled(false)
	await _fade_to_black()
	if _dream_rotator:
		_dream_rotator.call("stop_and_restore")
		_dream_rotator.queue_free()
		_dream_rotator = null
	_show_hud()
	_begin_day(DREAM_2_WAKE_DAY)


func _hide_hud() -> void :
	$CanvasLayer / HUD.visible = false


func _show_hud() -> void :
	$CanvasLayer / HUD.visible = true


func _hide_apartment_world() -> void :
	_hide_hud()
	for child in get_children():
		if child is Node3D and child != player:
			child.visible = false


func _show_apartment_world() -> void :
	for child in get_children():
		if child is Node3D:
			child.visible = true
	_show_hud()


func _fail(_reason: String) -> void :
	state = GameState.WRONG
	player.set_input_enabled(false)
	await $LossController.start_loss_sequence(player, fade_rect, $CanvasLayer)
	_start_run()


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
	morning_label.text = "اليوم: %d / %d" % [current_day, required_days - 1]
