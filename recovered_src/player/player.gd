class_name PlayerController
extends CharacterBody3D






const WALK_SPEED = 3.0
const SPRINT_SPEED = 5.0
const JUMP_VELOCITY = 4.0
const GRAVITY = 9.8

const BOB_FREQ = 2.4
const BOB_AMP = 0.05
const BASE_FOV = 75.0
const FOV_CHANGE = 1.5

const STEP_DISTANCE = 1.4
const STEP_MIN_PITCH = 0.94
const STEP_MAX_PITCH = 1.06
const STEP_VOLUME_DB = -8.0
const STEP_STREAMS_COUNT = 4

const LOOK_SMOOTHNESS: = 16.0
const LEAN_AMOUNT: = 0.014

var t_bob = 0.0
var target_yaw: float = 0.0
var target_pitch: float = 0.0

var input_enabled: bool = true
var current_interactable: Interactable = null


var sensitivity: float = 0.004


var step_distance: float = 0.0
var _step_streams: Array[AudioStream] = []

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head / Camera3D
@onready var interaction_ray: RayCast3D = $Head / Camera3D / InteractionRay
@onready var interact_prompt: Label = $CanvasLayer / InteractPrompt
@onready var footstep_player: AudioStreamPlayer = $FootstepPlayer


func _ready() -> void :
	sensitivity = Settings.mouse_sensitivity
	footstep_player.bus = Settings.SFX_BUS
	footstep_player.volume_db = STEP_VOLUME_DB
	for i in STEP_STREAMS_COUNT:
		_step_streams.append(load("res://audio/steps/wood_step_%d.ogg" % (i + 1)))
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func set_input_enabled(value: bool) -> void :
	input_enabled = value
	if not value:
		current_interactable = null
		if interact_prompt:
			interact_prompt.visible = false


func teleport_to(target: Transform3D) -> void :
	velocity = Vector3.ZERO
	global_transform = target
	step_distance = 0.0
	head.rotation.y = 0.0
	camera.rotation.x = 0.0
	camera.rotation.z = 0.0
	target_yaw = 0.0
	target_pitch = 0.0


func _unhandled_input(event: InputEvent) -> void :
	if not input_enabled:
		return
	if event is InputEventMouseMotion:
		target_yaw -= event.relative.x * sensitivity
		target_pitch -= event.relative.y * sensitivity
		target_pitch = clampf(target_pitch, deg_to_rad(-60), deg_to_rad(60))


func _physics_process(delta: float) -> void :
	if input_enabled:
		if not is_on_floor():
			velocity.y -= GRAVITY * delta

		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP_VELOCITY

		var input_dir: = Input.get_vector("left", "right", "up", "down")


		head.rotation.y = lerp_angle(head.rotation.y, target_yaw, LOOK_SMOOTHNESS * delta)
		camera.rotation.x = lerp_angle(camera.rotation.x, target_pitch, LOOK_SMOOTHNESS * delta)
		var target_roll: float = - input_dir.x * LEAN_AMOUNT
		camera.rotation.z = lerp_angle(camera.rotation.z, target_roll, LOOK_SMOOTHNESS * delta)

		var direction: = (head.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		var speed: float = SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED

		if is_on_floor():
			if direction:
				velocity.x = direction.x * speed
				velocity.z = direction.z * speed
			else:
				velocity.x = move_toward(velocity.x, 0, speed * delta * 7.0)
				velocity.z = move_toward(velocity.z, 0, speed * delta * 7.0)
		else:
			velocity.x = lerpf(velocity.x, direction.x * speed, delta * 3.0)
			velocity.z = lerpf(velocity.z, direction.z * speed, delta * 3.0)

		t_bob += delta * velocity.length() * float(is_on_floor())
		camera.transform.origin = _headbob(t_bob)

		if is_on_floor():
			step_distance += Vector2(velocity.x, velocity.z).length() * delta
			if step_distance >= STEP_DISTANCE:
				step_distance = 0.0
				_play_footstep()

		var velocity_clamped: float = clampf(velocity.length(), 0.5, SPRINT_SPEED * 2)
		var target_fov: float = BASE_FOV + FOV_CHANGE * velocity_clamped
		camera.fov = lerpf(camera.fov, target_fov, delta * 8.0)

		_update_interaction()

	move_and_slide()


func _update_interaction() -> void :
	var collider: Object = interaction_ray.get_collider()
	if collider is Interactable:
		current_interactable = collider
		interact_prompt.text = collider.prompt
		interact_prompt.visible = true
		if Input.is_action_just_pressed("interact"):
			collider.interact()
	else:
		current_interactable = null
		interact_prompt.visible = false


func _play_footstep() -> void :
	if _step_streams.is_empty():
		return
	footstep_player.stream = _step_streams[randi() % _step_streams.size()]
	footstep_player.pitch_scale = randf_range(STEP_MIN_PITCH, STEP_MAX_PITCH)
	footstep_player.play()


func _headbob(time: float) -> Vector3:
	var pos: = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos
