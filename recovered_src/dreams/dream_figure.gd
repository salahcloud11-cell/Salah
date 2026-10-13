extends Node3D






const FIGURE_Y: = 0.0

const HEAD_BONE_NAME: = "mixamorig_Head"
const LOOK_SPEED: = 8.0
const LOOK_YAW_LIMIT: = PI
const LOOK_PITCH_LIMIT: = 0.6



@export var head_look_rotation_offset: float = 90.0

var _skeleton: Skeleton3D = null
var _player: Node3D = null
var _head_bone: = -1
var _look_current: = Quaternion.IDENTITY


func _ready() -> void :
	for child in get_children():
		if child is Node3D:
			child.position.y = 0.0
	for ap in find_children("*", "AnimationPlayer", true, false):
		if ap is AnimationPlayer:
			ap.stop()
	_skeleton = _first_skeleton()
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
		position.y = FIGURE_Y - lowest
	_setup_head_look()


func _first_skeleton() -> Skeleton3D:
	for node in find_children("*", "Skeleton3D", true, false):
		if node is Skeleton3D:
			return node
	return null


func _setup_head_look() -> void :
	_player = _find_player()
	_head_bone = _find_head_bone()
	_look_current = Quaternion.IDENTITY


func _find_player() -> Node3D:
	var node: Node = self
	while node:
		var p: = node.get_node_or_null("Player")
		if p is Node3D:
			return p
		node = node.get_parent()
	return null


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


func _physics_process(delta: float) -> void :
	_look_at_player(delta)


func _look_at_player(delta: float) -> void :
	if _skeleton == null or _player == null:
		return
	if _head_bone == -1:
		_head_bone = _find_head_bone()
		if _head_bone == -1:
			return
	var head_world: Vector3 = _skeleton.to_global(_skeleton.get_bone_global_pose(_head_bone).origin)
	var target: Vector3 = _player.global_position
	var head_node: = _player.get_node_or_null("Head")
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
