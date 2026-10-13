extends Node3D

@export var seat_height: float = 0.42
@export var character_scale: float = 0.9

const HIP_PITCH: = -90.0
const SPINE_PITCH: = 90.0
const KNEE_PITCH: = 90.0
const ARM_ROLL: = 75.0

func _ready() -> void :
	scale = Vector3.ONE * character_scale
	var skeleton: = _find_skeleton()
	if skeleton == null:
		push_warning("[CharacterPose] No Skeleton3D found under %s" % name)
		return
	for anim in find_children("*", "AnimationPlayer", true, false):
		if anim is AnimationPlayer:
			anim.stop()
	_apply_pose(skeleton)
	_sit_on_seat(skeleton)

func _find_skeleton() -> Skeleton3D:
	for child in find_children("*", "*", true, false):
		if child is Skeleton3D:
			return child
	return null

func _apply_pose(skeleton: Skeleton3D) -> void :
	_rotate_bone(skeleton, "Hips", Vector3(deg_to_rad(HIP_PITCH), 0, 0))
	for bone in ["Spine", "Spine1", "Spine2"]:
		_rotate_bone(skeleton, bone, Vector3(deg_to_rad(SPINE_PITCH), 0, 0))
	_rotate_bone(skeleton, "LeftUpLeg", Vector3.ZERO)
	_rotate_bone(skeleton, "RightUpLeg", Vector3.ZERO)
	_rotate_bone(skeleton, "LeftLeg", Vector3(deg_to_rad(KNEE_PITCH), 0, 0))
	_rotate_bone(skeleton, "RightLeg", Vector3(deg_to_rad(KNEE_PITCH), 0, 0))
	_rotate_bone(skeleton, "LeftArm", Vector3(0, 0, deg_to_rad(ARM_ROLL)))
	_rotate_bone(skeleton, "RightArm", Vector3(0, 0, deg_to_rad( - ARM_ROLL)))

func _rotate_bone(skeleton: Skeleton3D, bone_name: String, euler: Vector3) -> void :
	var idx: = skeleton.find_bone(bone_name)
	if idx == -1:
		return
	skeleton.set_bone_pose_rotation(idx, Quaternion.from_euler(euler))
	skeleton.reset_bone_pose_position(idx)

func _sit_on_seat(skeleton: Skeleton3D) -> void :
	var idx: = skeleton.find_bone("Hips")
	if idx == -1:
		return
	var rest_height: float = skeleton.get_bone_global_rest_pose(idx).origin.y * character_scale
	position.y = seat_height - rest_height
