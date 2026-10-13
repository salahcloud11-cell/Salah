class_name DreamCorridor
extends Node3D






signal finished

const LIGHT_ENERGY: = 6.0
const LIGHT_TRIGGER_COUNT: = 6
const CHASE_DELAY: = 0.7
const CATCH_DISTANCE: = 1.5
const END_PAUSE: = 0.6
const FAILSAFE_TIME: = 120.0


const CHASE_RED: = Color(1.0, 0.05, 0.03)
const CHASE_AMBIENT: = Color(0.3, 0.04, 0.03)

const DRONE_MIX_RATE: = 11025

@onready var player: PlayerController = $Player
@onready var chaser: DreamChaser = $FinalFigure
@onready var drone_player: AudioStreamPlayer = $Drone
@onready var sting_player: AudioStreamPlayer = $Sting
@onready var chase_music: AudioStreamPlayer = $ChaseMusic
@onready var hit_sound: AudioStreamPlayer = $HitSound

var _caught: = false
var _chasing: = false


func _ready() -> void :
	player.get_node("Head/Camera3D").make_current()
	_connect_triggers()
	_setup_audio()
	_run_failsafe()


func _connect_triggers() -> void :
	for i in range(1, LIGHT_TRIGGER_COUNT + 1):
		var trigger: = get_node_or_null("Triggers/Trigger%d" % i) as Area3D
		if trigger:
			trigger.body_entered.connect(_on_trigger.bind(i))


func _on_trigger(body: Node3D, index: int) -> void :
	if body != player:
		return
	_light_on(index)
	if index == LIGHT_TRIGGER_COUNT and not _chasing:
		_start_chase()


func _light_on(index: int) -> void :
	var light: = get_node_or_null("Lights/Light%d" % index)
	if light == null:
		return
	var tw: = create_tween()
	tw.tween_property(light, "light_energy", LIGHT_ENERGY, 0.6).from(0.0)


func _start_chase() -> void :
	_chasing = true
	_make_red()
	MusicPlayer.stop_music()
	chase_music.play()
	chaser.twist()
	player.set_input_enabled(false)
	chaser.look_at(player.global_position, Vector3.UP)
	await get_tree().create_timer(CHASE_DELAY).timeout
	if _caught:
		return
	chaser.start_chase()
	player.set_input_enabled(true)



func _make_red() -> void :
	for i in range(1, LIGHT_TRIGGER_COUNT + 1):
		var light: = get_node_or_null("Lights/Light%d" % i) as OmniLight3D
		if light:
			var tw: = create_tween()
			tw.tween_property(light, "light_color", CHASE_RED, 0.4)
	var env: = get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env and env.environment:
		create_tween().tween_property(env.environment, "ambient_light_color", CHASE_AMBIENT, 0.5)
		create_tween().tween_property(env.environment, "fog_light_color", CHASE_AMBIENT, 0.5)


func _physics_process(_delta: float) -> void :
	if _caught or not _chasing or not chaser.chasing:
		return
	if player.global_position.distance_to(chaser.global_position) < CATCH_DISTANCE:
		_on_caught()


func _on_caught() -> void :
	if _caught:
		return
	_caught = true
	chaser.chasing = false
	player.set_input_enabled(false)
	chase_music.stop()
	hit_sound.play()
	await _look_at_enemy()
	await get_tree().create_timer(END_PAUSE).timeout
	MusicPlayer.play_music()
	finished.emit()



func _look_at_enemy() -> void :
	var head: Node3D = player.get_node("Head")
	var cam: Camera3D = player.get_node("Head/Camera3D")
	var dir: Vector3 = chaser.global_position - head.global_position
	if dir.length_squared() < 0.0001 or absf(dir.normalized().dot(Vector3.UP)) > 0.99:
		return
	var euler: Vector3 = Transform3D().looking_at(dir, Vector3.UP).basis.get_euler()
	var tween: = create_tween()
	tween.set_parallel(true)
	tween.tween_property(head, "rotation", Vector3(euler.x, euler.y, 0.0), 0.3)\
	.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(cam, "rotation:x", 0.0, 0.3)
	tween.tween_property(cam, "fov", 88.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.35).timeout


func _run_failsafe() -> void :
	await get_tree().create_timer(FAILSAFE_TIME).timeout
	if not _caught:
		_on_caught()


func _setup_audio() -> void :
	drone_player.bus = Settings.SFX_BUS
	drone_player.stream = _make_drone()
	drone_player.play()
	sting_player.bus = Settings.SFX_BUS
	sting_player.stream = _make_sting()
	chase_music.bus = Settings.MUSIC_BUS
	if chase_music.stream is AudioStreamMP3:
		(chase_music.stream as AudioStreamMP3).loop = true
	hit_sound.bus = Settings.SFX_BUS



func _make_drone() -> AudioStreamWAV:
	var sample_count: = int(8.0 * DRONE_MIX_RATE)
	var data: = PackedByteArray()
	data.resize(sample_count * 2)
	for i in sample_count:
		var t: = float(i) / DRONE_MIX_RATE
		var s: = sin(TAU * 55.0 * t) * 0.5 + sin(TAU * 82.5 * t) * 0.35
		s *= 0.7 + 0.3 * sin(TAU * 0.25 * t)
		s *= 0.09
		var v: = int(clampf(s, -1.0, 1.0) * 32767.0)
		data[i * 2] = v & 255
		data[i * 2 + 1] = (v >> 8) & 255
	var wav: = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = DRONE_MIX_RATE
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = sample_count
	wav.data = data
	return wav



func _make_sting() -> AudioStreamWAV:
	var duration: = 0.7
	var sample_count: = int(duration * DRONE_MIX_RATE)
	var data: = PackedByteArray()
	data.resize(sample_count * 2)
	for i in sample_count:
		var t: = float(i) / DRONE_MIX_RATE
		var f: = 180.0 - 90.0 * (t / duration)
		var s: = sin(TAU * f * t) * exp(-4.0 * t)
		s += 0.5 * sin(TAU * 130.0 * t) * exp(-6.0 * t)
		s *= 0.24
		var v: = int(clampf(s, -1.0, 1.0) * 32767.0)
		data[i * 2] = v & 255
		data[i * 2 + 1] = (v >> 8) & 255
	var wav: = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = DRONE_MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav
