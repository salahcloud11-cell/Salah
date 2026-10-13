class_name DreamChaser
extends Node3D






const CHASE_SPEED: = 6.5


const TWIST_MIN: = 0.35
const TWIST_MAX: = 2.4
const BIG_TWIST_CHANCE: = 0.18
const BIG_TWIST_AMOUNT: = PI


const GAIT_AMP_MIN: = 0.25
const GAIT_AMP_MAX: = 1.2
const GAIT_SPEED_MIN: = 7.0
const GAIT_SPEED_MAX: = 16.0


const TWITCH_CHANCE: = 0.08
const TWITCH_AMOUNT: = 0.9


const HOP_AMOUNT: = 0.05
const HOP_FREQ: = 14.0


const HEAD_BONE_NAME: = "mixamorig_Head"
const LOOK_SPEED: = 8.0
const LOOK_YAW_LIMIT: = PI
const LOOK_PITCH_LIMIT: = 0.6



@export var head_look_rotation_offset: float = 90.0

var chasing: bool = false

var _skeleton: Skeleton3D = null
var _base_y: float = 0.0
var _time: = 0.0
var _head_bone: = -1
var _look_current: = Quaternion.IDENTITY
var _bone_base: Array[Quaternion] = []
var _bone_axis: Array[Vector3] = []
var _bone_phase: Array[float] = []
var _bone_amp: Array[float] = []
var _bone_speed: Array[float] = []

@onready var player: Node3D = get_node("../Player")


func _ready() -> void :
	_skeleton = _find_skeleton()
	_stand_up()
	_base_y = global_position.y
	_head_bone = _find_head_bone()
	_look_current = Quaternion.IDENTITY


func _find_skeleton() -> Skeleton3D:
	for node in find_children("*", "Skeleton3D", true, false):
		if node is Skeleton3D:
			return node
	return null




func _stand_up() -> void :
	for child in get_children():
		if child is Node3D:
			child.position.y = 0.0
	for ap in find_children("*", "AnimationPlayer", true, false):
		if ap is AnimationPlayer:
			ap.stop()
	if _skeleton == null:
		return
	for i in _skeleton.get_bone_count():
		_skeleton.reset_bone_pose(i)
	var lowest: = 0.0
	var has_bone: = false
	for i in _skeleton.get_bone_count():
		var y: = _skeleton.get_bone_global_pose(i).origin.y
		if not has_bone or y < lowest:
			lowest = y
			has_bone = true
	if has_bone:
		position.y -= lowest



func twist() -> void :
	if _skeleton == null:
		return
	_bone_base.clear()
	_bone_axis.clear()
	_bone_phase.clear()
	_bone_amp.clear()
	_bone_speed.clear()
	for i in _skeleton.get_bone_count():
		var euler: = Vector3(
			_rand_signed(TWIST_MIN, TWIST_MAX), 
			_rand_signed(TWIST_MIN, TWIST_MAX), 
			_rand_signed(TWIST_MIN, TWIST_MAX)
		)
		if randf() < BIG_TWIST_CHANCE:
			euler += Vector3(_rand_signed(0.0, BIG_TWIST_AMOUNT), 
				_rand_signed(0.0, BIG_TWIST_AMOUNT), 
				_rand_signed(0.0, BIG_TWIST_AMOUNT))
		var axis: = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
		if axis.length_squared() < 0.01:
			axis = Vector3.UP
		_bone_base.append(Quaternion.from_euler(euler))
		_bone_axis.append(axis.normalized())
		_bone_phase.append(randf() * TAU)
		_bone_amp.append(randf_range(GAIT_AMP_MIN, GAIT_AMP_MAX))
		_bone_speed.append(randf_range(GAIT_SPEED_MIN, GAIT_SPEED_MAX))
		_skeleton.set_bone_pose_rotation(i, _bone_base[i])


func _rand_signed(from: float, to: float) -> float:
	var v: = randf_range(from, to)
	return - v if randf() < 0.5 else v


func start_chase() -> void :
	chasing = true


func _physics_process(delta: float) -> void :
	if chasing and player != null:
		_time += delta
		_animate_bones()
		global_position.y = _base_y + sin(_time * HOP_FREQ) * HOP_AMOUNT
		if randf() < TWITCH_CHANCE and _skeleton and _skeleton.get_bone_count() > 0:
			var i: = randi() % _skeleton.get_bone_count()
			var twitch: = Quaternion(Vector3.RIGHT, _rand_signed(0.0, TWITCH_AMOUNT))\
			* Quaternion(Vector3.UP, _rand_signed(0.0, TWITCH_AMOUNT))
			_skeleton.set_bone_pose_rotation(i, _bone_base[i] * twitch)
		var offset: Vector3 = player.global_position - global_position
		var dist: = offset.length()
		if dist >= 0.01:
			global_position += offset / dist * CHASE_SPEED * delta
			look_at(player.global_position, Vector3.UP)
	_look_at_player(delta)


func _find_head_bone() -> int:
	if _skeleton == null:
		return -1
	for i in _skeleton.get_bone_count():
		if _skeleton.get_bone_name(i) == HEAD_BONE_NAME:
			return i
	for i in _skeleton.get_bone_count():
		var bone_name: String = _skeleton.get_bone_name(i)
		if bone_name.ends_with("_Head") or bone_name == "Head":
			return i
	return -1


func _look_at_player(delta: float) -> void :
	if _skeleton == null or player == null:
		return
	if _head_bone == -1:
		_head_bone = _find_head_bone()
		if _head_bone == -1:
			return
	var head_world: Vector3 = _skeleton.to_global(_skeleton.get_bone_global_pose(_head_bone).origin)
	var target: Vector3 = player.global_position
	var head_node: = player.get_node_or_null("Head")
	if head_node is Node3D:
		target = head_node.global_position
	var dir: Vector3 = target - head_world
	if dir.length_squared() < 0.0001 or absf(dir.normalized().dot(Vector3.UP)) > 0.99:
		return
	var dir_skeleton: Vector3 = (_skeleton.global_transform.affine_inverse().basis * dir).normalized()
	if absf(dir_skeleton.dot(Vector3.UP)) > 0.99:
		return
	var desired: Basis = (Transform3D().looking_at(dir_skeleton, Vector3.UP).basis\
	* Basis(Vector3.UP, deg_to_rad(head_look_rotation_offset)))
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


func _animate_bones() -> void :
	if _skeleton == null or _bone_base.is_empty():
		return
	for i in _skeleton.get_bone_count():
		if i >= _bone_base.size():
			break
		var sway: = Quaternion(_bone_axis[i], sin(_time * _bone_speed[i] + _bone_phase[i]) * _bone_amp[i])
		_skeleton.set_bone_pose_rotation(i, _bone_base[i] * sway)
