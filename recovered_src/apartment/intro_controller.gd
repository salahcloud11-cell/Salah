extends Node3D





signal finished






const SHOTS: = [
	{
		"camera": "Shot01_FrontDoor", 
		"lines": [
			"دخلت وظيفة جديدة دوامها مره سهل", 

		], 
		"line_time": 2.8, 
		"hold": 0.0, 
	}, 
	{
		"camera": "Shot02_ApartmentWide", 
		"lines": [
			"لازم اصحى بدري كل يوم اثنين واروح المكتب", 
		], 
		"line_time": 3.0, 
		"hold": 0.0, 
	}, 
	{
		"camera": "Shot03_DiningTable", 
		"lines": [
			"لكن امس كان في عزيمة...", 
			"ولعلي تأخرت في النوم", 
		], 
		"line_time": 2.1, 
		"hold": 0.0, 
	}, 
	{
		"camera": "Shot04_GeneralUneasy", 
		"lines": [
			"راسي كان مصددع بس مايهم..", 
		], 
		"line_time": 2.0, 
		"hold": 0.0, 
	}, 
	{
		"camera": "Shot05_Bedroom", 
		"lines": [
			"لازم انام عشان ما اتاخر على اول يوم في الوظيفة.", 
		], 
		"line_time": 3.0, 
		"hold": 1.2, 
	}, 
]


const AMBIENT_PATH: = "res://audio/intro_ambient.mp3"

const AMBIENT_LEVEL_DB: = -16.0
const AMBIENT_FADE_SEC: = 1.2


const AMBIENT_ROOM_PATH: = "res://audio/ambient_empty_room.mp3"
const AMBIENT_ROOM_LEVEL_DB: = -20.0


const VO_PATH: = "res://audio/voice_over_intro.mp3"
const VO_LEVEL_DB: = -1.0
const VO_BUS: = "VO_Intro"
const VO_REVERB_WET: = 0.08
const VO_REVERB_ROOM: = 0.25
const VO_NOISE_DB: = -30.0
const VO_NOISE_AMP: = 0.06


const PSXVoice: = preload("res://audio/psx_voice.gd")


const BUS_MUSIC: = "Music"
const BUS_SFX: = "SFX"


const FADE_IN_START_SEC: = 1.0
const FINAL_FADE_OUT_SEC: = 0.6

var _active: = false
var _advance: = false
var _skipped: = false
var _player: PlayerController = null
var _fade_rect: ColorRect = null
var _canvas_layer: CanvasLayer = null
var _ambient: AudioStreamPlayer = null
var _ambient_room: AudioStreamPlayer = null
var _voice: AudioStreamPlayer = null
var _noise: AudioStreamPlayer = null
var _text_tween: Tween = null

@onready var cameras: Node3D = $IntroCameras
@onready var ui_layer: CanvasLayer = $IntroUI
@onready var text_label: Label = $IntroUI / Text
@onready var text_background: ColorRect = $IntroUI / Background


func play_intro(player: PlayerController, fade_rect: ColorRect, canvas_layer: CanvasLayer, anomaly_manager: AnomalyManager) -> void :
	_player = player
	_fade_rect = fade_rect
	_canvas_layer = canvas_layer
	_active = true
	_advance = false
	_skipped = false



	if anomaly_manager:
		anomaly_manager.reset_round()

	_music_player_call("stop_music")
	_setup_ambient()
	_setup_voice()

	player.set_input_enabled(false)
	player.visible = false
	ui_layer.visible = true
	_hide_gameplay_ui()

	_play_ambient(true)
	_change_cam(SHOTS[0]["camera"])
	await _fade_from_black(FADE_IN_START_SEC)
	_start_voice()
	await get_tree().create_timer(0.3).timeout

	for index in SHOTS.size():
		if _skipped:
			break
		var shot: Dictionary = SHOTS[index]
		for line in shot["lines"]:
			if _skipped:
				break
			_show_line(line)
			await _wait_or_advance(shot["line_time"])
			_hide_line()
		if _skipped:
			break
		await _wait_or_advance(shot["hold"])
		if _skipped:
			break
		if index < SHOTS.size() - 1:
			_change_cam(SHOTS[index + 1]["camera"])
			await get_tree().create_timer(0.25).timeout

	_hide_line()
	await _fade_to_black(FINAL_FADE_OUT_SEC)
	_finish()



func _finish() -> void :
	_play_ambient(false)
	_music_player_call("play_music")
	if _voice:
		_voice.stop()
	if _noise:
		_noise.stop()
	ui_layer.visible = false
	if _player:
		_player.visible = true
		if _player.has_node("Head/Camera3D"):
			_player.get_node("Head/Camera3D").make_current()
	_show_gameplay_ui()
	_active = false
	finished.emit()


func _change_cam(cam_name: String) -> void :
	var cam: = cameras.get_node_or_null(cam_name) as Camera3D
	if cam:
		cam.make_current()


func _show_line(text: String) -> void :
	if _text_tween:
		_text_tween.kill()
	text_label.text = text
	text_background.visible = true
	text_label.modulate.a = 0.0
	text_label.visible = true
	_text_tween = create_tween()
	_text_tween.tween_property(text_label, "modulate:a", 1.0, 0.35)


func _hide_line() -> void :
	if _text_tween:
		_text_tween.kill()
		_text_tween = null
	text_label.modulate.a = 0.0
	text_label.visible = false
	text_background.visible = false



func _wait_or_advance(duration: float) -> void :
	if duration <= 0.0:
		return
	var timer: = get_tree().create_timer(duration)
	_advance = false
	while not _advance and not _skipped and timer.time_left > 0.0:
		await get_tree().process_frame


func _hide_gameplay_ui() -> void :
	if _canvas_layer == null:
		return
	for node_name in ["HUD", "CenterMessage"]:
		var node: = _canvas_layer.get_node_or_null(node_name)
		if node is CanvasItem:
			(node as CanvasItem).visible = false


func _show_gameplay_ui() -> void :
	if _canvas_layer == null:
		return
	var hud: = _canvas_layer.get_node_or_null("HUD")
	if hud is CanvasItem:
		(hud as CanvasItem).visible = true
	var center_message: = _canvas_layer.get_node_or_null("CenterMessage")
	if center_message is CanvasItem:
		(center_message as CanvasItem).visible = false


func _setup_ambient() -> void :
	if _ambient:
		return
	_ambient = AudioStreamPlayer.new()
	_ambient.name = "IntroAmbient"
	_ambient.bus = BUS_MUSIC
	var stream: = load(AMBIENT_PATH) as AudioStream
	if stream:
		_ambient.stream = stream
		if stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = true
	_ambient.volume_db = -40.0
	add_child(_ambient)
	_ambient_room = AudioStreamPlayer.new()
	_ambient_room.name = "IntroRoomTone"
	_ambient_room.bus = BUS_MUSIC
	var room_stream: = load(AMBIENT_ROOM_PATH) as AudioStream
	if room_stream:
		_ambient_room.stream = room_stream
		if room_stream is AudioStreamMP3:
			(room_stream as AudioStreamMP3).loop = true
	_ambient_room.volume_db = -40.0
	add_child(_ambient_room)


func _setup_voice() -> void :
	if _voice:
		return
	PSXVoice.ensure_bus(VO_BUS, VO_REVERB_WET, VO_REVERB_ROOM)
	_voice = AudioStreamPlayer.new()
	_voice.name = "IntroVoice"
	_voice.bus = VO_BUS
	_voice.stream = load(VO_PATH) as AudioStream
	_voice.volume_db = VO_LEVEL_DB
	add_child(_voice)
	_noise = PSXVoice.add_noise(self, VO_BUS, VO_NOISE_DB, VO_NOISE_AMP)


func _start_voice() -> void :
	if _voice and _voice.stream:
		_voice.play()
	if _noise:
		_noise.play()





func _music_player_call(method: String) -> void :
	var music: = get_node_or_null("/root/MusicPlayer")
	if music:
		music.call(method)


func _play_ambient(fade_in: bool) -> void :
	var players: = [_ambient, _ambient_room]
	var targets: = [AMBIENT_LEVEL_DB, AMBIENT_ROOM_LEVEL_DB]
	if fade_in:
		var tw: = create_tween()
		tw.set_parallel(true)
		for i in players.size():
			var p = players[i]
			if p == null or p.stream == null:
				continue
			if not p.playing:
				p.volume_db = -40.0
				p.play()
			tw.tween_property(p, "volume_db", targets[i], AMBIENT_FADE_SEC)
	else:
		var tw: = create_tween()
		tw.set_parallel(true)
		for i in players.size():
			var p = players[i]
			if p == null or p.stream == null:
				continue
			tw.tween_property(p, "volume_db", -40.0, AMBIENT_FADE_SEC)
		await tw.finished
		for p in players:
			if p:
				p.stop()


func _fade_to_black(duration: float = 0.6) -> void :
	var tw: = create_tween()
	tw.tween_property(_fade_rect, "color:a", 1.0, duration)
	await tw.finished


func _fade_from_black(duration: float = 1.0) -> void :
	_fade_rect.color.a = 1.0
	var tw: = create_tween()
	tw.tween_property(_fade_rect, "color:a", 0.0, duration)
	await tw.finished


func _unhandled_input(event: InputEvent) -> void :
	if not _active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_skipped = true
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_advance = true
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_advance = true
			get_viewport().set_input_as_handled()
