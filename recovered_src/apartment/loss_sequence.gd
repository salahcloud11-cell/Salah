extends Node3D








signal finished


const LOSS_AUDIO_PATH: = "res://audio/losing.mp3"


const CHASE_MUSIC_PATH: = "res://audio/chase_music.mp3"
const CHASE_MUSIC_LEVEL_DB: = -10.0


const VO_BUS: = "VO_Loss"
const VO_REVERB_WET: = 0.3
const VO_REVERB_ROOM: = 0.6
const VO_NOISE_DB_START: = -26.0
const VO_NOISE_DB_END: = -16.0
const VO_NOISE_AMP: = 0.15


const PSXVoice: = preload("res://audio/psx_voice.gd")


const CAMERA_MOVE_SEC: = 0.7
const FINAL_FLASH_SEC: = 0.15
const FADE_OUT_SEC: = 0.35




const FRAME_OFFSET: = Vector3(-0.9, 0.0, -1.7)
const ZOOM_OFFSET: = Vector3(-0.45, 0.0, -1.05)


const FOV_START: = 75.0
const FOV_END: = 50.0


const HEAD_BONE_NAME: = "mixamorig_Head"
const LOOK_SPEED: = 8.0
const LOOK_PITCH_LIMIT: = 0.6
const LOOK_YAW_LIMIT: = PI


const HEAD_LOOK_OFFSET: = 90.0


@export var loss_start_volume_db: float = -3.0
@export var loss_end_volume_db: float = 10.0
@export var loss_red_max_alpha: float = 0.8
@export var shake_start_amp: float = 0.005
@export var shake_end_amp: float = 0.06
@export var shake_rot_deg: float = 0.6

var _player: PlayerController = null
var _fade_rect: ColorRect = null
var _canvas_layer: CanvasLayer = null
var _skeleton: Skeleton3D = null
var _head_bone: = -1
var _voice: AudioStreamPlayer = null
var _music: AudioStreamPlayer = null
var _noise: AudioStreamPlayer = null

var _active: = false
var _elapsed: = 0.0
var _audio_progress: = 0.0
var _audio_len: = 1.0
var _audio_started: = false
var _ended: = false
var _start_pos: = Vector3.ZERO
var _frame_pos: = Vector3.ZERO
var _close_pos: = Vector3.ZERO
var _head_pos: = Vector3.ZERO
var _look_current: = Quaternion.IDENTITY

@onready var camera: Camera3D = $LossCamera
@onready var red_rect: ColorRect = $RedLayer / RedRect


func start_loss_sequence(player: PlayerController, fade_rect: ColorRect, canvas_layer: CanvasLayer) -> void :
	_player = player
	_fade_rect = fade_rect
	_canvas_layer = canvas_layer
	_active = true
	_elapsed = 0.0
	_audio_progress = 0.0
	_audio_started = false
	_ended = false
	_look_current = Quaternion.IDENTITY
	red_rect.color.a = 0.0

	_hide_gameplay_ui()
	_find_character()
	_setup_voice()
	_setup_music()

	_music_player_call("stop_music")
	if _music and _music.stream:
		_music.play()

	camera.fov = FOV_START
	camera.make_current()

	_head_pos = _head_world_position()
	_start_pos = camera.global_position
	_frame_pos = _head_pos + FRAME_OFFSET
	_close_pos = _head_pos + ZOOM_OFFSET


	await finished


func _process(delta: float) -> void :
	if not _active:
		return
	_elapsed += delta
	_update_head_look(delta)

	if not _audio_started:
		var p: = clampf(_elapsed / CAMERA_MOVE_SEC, 0.0, 1.0)
		var eased: = smoothstep(0.0, 1.0, p)
		camera.global_position = _start_pos.lerp(_frame_pos, eased)
		camera.look_at(_head_pos, Vector3.UP)
		if _elapsed >= CAMERA_MOVE_SEC:
			_start_audio()
		return

	_audio_progress = clampf((_elapsed - CAMERA_MOVE_SEC) / _audio_len, 0.0, 1.0)
	var intensity: = _audio_progress * _audio_progress

	var zoom_p: = _audio_progress
	camera.global_position = _frame_pos.lerp(_close_pos, zoom_p) + _shake_offset(intensity)
	camera.look_at(_head_pos, Vector3.UP)
	camera.fov = lerpf(FOV_START, FOV_END, zoom_p)
	var rot_shake: = deg_to_rad(shake_rot_deg * intensity)
	camera.rotate_object_local(Vector3.UP, randf_range( - rot_shake, rot_shake))
	camera.rotate_object_local(Vector3.RIGHT, randf_range( - rot_shake, rot_shake) * 0.5)

	red_rect.color.a = lerpf(0.0, loss_red_max_alpha, intensity)

	if _voice:
		_voice.volume_db = lerpf(loss_start_volume_db, loss_end_volume_db, intensity)
	if _noise:
		_noise.volume_db = lerpf(VO_NOISE_DB_START, VO_NOISE_DB_END, intensity)


func _shake_offset(intensity: float) -> Vector3:
	var amp: float = lerpf(shake_start_amp, shake_end_amp, intensity)
	return Vector3(
		randf_range( - amp, amp), 
		randf_range( - amp, amp), 
		randf_range( - amp, amp)
	)


func _start_audio() -> void :
	_audio_started = true
	if _voice and _voice.stream:
		_audio_len = maxf(_voice.stream.get_length(), 0.01)
		_voice.play()
		if _noise:
			_noise.play()
	else:

		get_tree().create_timer(5.3).timeout.connect(_end_sequence)


func _on_voice_finished() -> void :
	_end_sequence()


func _end_sequence() -> void :
	if _ended:
		return
	_ended = true
	_active = false
	red_rect.color.a = loss_red_max_alpha
	await get_tree().create_timer(FINAL_FLASH_SEC).timeout
	var tw: = create_tween()
	tw.tween_property(_fade_rect, "color:a", 1.0, FADE_OUT_SEC)
	await tw.finished
	_cleanup()
	finished.emit()


func _cleanup() -> void :
	_active = false
	_ended = true
	if _voice:
		_voice.stop()
	if _noise:
		_noise.stop()
	if _music:
		_music.stop()
	_music_player_call("play_music")
	red_rect.color.a = 0.0
	camera.fov = FOV_START
	camera.current = false
	if _player and _player.has_node("Head/Camera3D"):
		_player.get_node("Head/Camera3D").make_current()
	if _skeleton and _head_bone != -1:
		_skeleton.reset_bone_pose(_head_bone)
	_look_current = Quaternion.IDENTITY
	_show_gameplay_ui()


func _find_character() -> void :
	var root: = get_parent()
	var anomaly: = root.get_node_or_null("LivingRoom/LivingCharacterAnomaly") as AnomalyObject
	if anomaly:
		anomaly.activate_variant(0)
	var skeleton_node: = root.get_node_or_null(
		"LivingRoom/LivingCharacterAnomaly/Variants/Normal/Man/Model/Skeleton3D")
	if skeleton_node is Skeleton3D:
		_skeleton = skeleton_node
		_head_bone = _find_head_bone()


func _find_head_bone() -> int:
	if _skeleton == null:
		return -1
	for i in _skeleton.get_bone_count():
		if _skeleton.get_bone_name(i) == HEAD_BONE_NAME:
			return i
	return -1


func _head_world_position() -> Vector3:
	if _skeleton and _head_bone != -1:
		return _skeleton.to_global(_skeleton.get_bone_global_pose(_head_bone).origin)
	return camera.global_position + Vector3(0.0, 1.4, 0.0)


func _setup_voice() -> void :
	if _voice:
		return
	PSXVoice.ensure_bus(VO_BUS, VO_REVERB_WET, VO_REVERB_ROOM)
	_voice = AudioStreamPlayer.new()
	_voice.name = "LossVoice"
	_voice.bus = VO_BUS
	var stream: = load(LOSS_AUDIO_PATH) as AudioStream
	if stream:
		_voice.stream = stream
		if stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = false
	_voice.volume_db = loss_start_volume_db
	_voice.finished.connect(_on_voice_finished)
	add_child(_voice)
	_noise = PSXVoice.add_noise(self, VO_BUS, VO_NOISE_DB_START, VO_NOISE_AMP)


func _setup_music() -> void :
	if _music:
		return
	_music = AudioStreamPlayer.new()
	_music.name = "LossChaseMusic"
	_music.bus = "Music"
	var stream: = load(CHASE_MUSIC_PATH) as AudioStream
	if stream:
		_music.stream = stream
		if stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = true
	_music.volume_db = CHASE_MUSIC_LEVEL_DB
	add_child(_music)




func _music_player_call(method: String) -> void :
	var music: = get_node_or_null("/root/MusicPlayer")
	if music:
		music.call(method)


func _update_head_look(delta: float) -> void :
	if _skeleton == null or _head_bone == -1:
		return
	var head_world: Vector3 = _head_world_position()
	var target: Vector3 = camera.global_position
	var dir: Vector3 = target - head_world
	if dir.length_squared() < 0.0001 or absf(dir.normalized().dot(Vector3.UP)) > 0.99:
		return
	var dir_skeleton: Vector3 = (_skeleton.global_transform.affine_inverse().basis * dir).normalized()
	if absf(dir_skeleton.dot(Vector3.UP)) > 0.99:
		return
	var desired: Basis = (Transform3D().looking_at(dir_skeleton, Vector3.UP).basis\
	* Basis(Vector3.UP, deg_to_rad(HEAD_LOOK_OFFSET)))
	var parent_idx: = _skeleton.get_bone_parent(_head_bone)
	if parent_idx == -1:
		return
	var parent_rot: Basis = _skeleton.get_bone_global_pose(parent_idx).basis
	var local: Quaternion = (parent_rot.inverse() * desired).get_rotation_quaternion()
	var e: = local.get_euler()
	e.x = clampf(e.x, - LOOK_PITCH_LIMIT, LOOK_PITCH_LIMIT)
	e.y = clampf(e.y, - LOOK_YAW_LIMIT, LOOK_YAW_LIMIT)
	e.z = 0.0
	local = Quaternion.from_euler(e)
	_look_current = _look_current.slerp(local, clampf(delta * LOOK_SPEED, 0.0, 1.0))
	_skeleton.set_bone_pose_rotation(_head_bone, _look_current)


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
