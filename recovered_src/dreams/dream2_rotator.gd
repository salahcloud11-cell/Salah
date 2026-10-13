extends Node3D






const ROOMS: = ["Bedroom", "Hallway", "LivingRoom", "Bathroom", "Kitchen", "Dining"]
const EXCLUDE: = ["Bed", "Counter"]
const SPEED_MIN: = 0.2
const SPEED_MAX: = 1.0
const SKIP_CHANCE: = 0.2


const DREAM_RED: = Color(1.0, 0.05, 0.03)
const DREAM_AMBIENT: = Color(0.3, 0.04, 0.03)

const LIGHT_TYPES: = ["OmniLight3D", "SpotLight3D", "DirectionalLight3D"]

var _targets: Array[Node3D] = []
var _axes: Dictionary = {}
var _speeds: Dictionary = {}
var _originals: Dictionary = {}
var _light_colors: Dictionary = {}
var _environment: Environment = null
var _ambient_original: = Color.WHITE
var _fog_original: = Color.WHITE
var _active: = true


func _ready() -> void :
	var root: = get_parent()
	for room_name in ROOMS:
		var room: = root.get_node_or_null(room_name)
		if room == null:
			continue
		var furniture: = room.get_node_or_null("Furniture")
		if furniture == null:
			continue
		for piece in furniture.get_children():
			if piece is Node3D and not EXCLUDE.has(piece.name):
				if randf() < SKIP_CHANCE:
					continue
				_add_target(piece as Node3D)
	for piece in _targets:
		_originals[piece] = piece.transform
	_make_red(root)


func _add_target(piece: Node3D) -> void :
	var axes: Array = [Vector3.UP, Vector3.RIGHT, Vector3.FORWARD, Vector3(1, 1, 0).normalized()]
	var axis: Vector3 = axes[randi() % axes.size()]
	if randi() % 2 == 0:
		axis = - axis
	var speed: = randf_range(SPEED_MIN, SPEED_MAX) * (1.0 if randf() < 0.5 else -1.0)
	_targets.append(piece)
	_axes[piece] = axis
	_speeds[piece] = speed




func _make_red(root: Node) -> void :
	for light_type in LIGHT_TYPES:
		for node in root.find_children("*", light_type, true, false):
			if node is Light3D:
				_light_colors[node] = node.light_color
				node.light_color = DREAM_RED
	for node in root.find_children("*", "WorldEnvironment", true, false):
		var env: = node as WorldEnvironment
		if env and env.environment:
			_environment = env.environment
			_ambient_original = _environment.ambient_light_color
			_fog_original = _environment.fog_light_color
			_environment.ambient_light_color = DREAM_AMBIENT
			_environment.fog_light_color = DREAM_AMBIENT
			break


func _process(delta: float) -> void :
	if not _active:
		return
	for piece in _targets:
		piece.rotate(_axes[piece] as Vector3, _speeds[piece] * delta)


func stop_and_restore() -> void :
	_active = false
	for piece in _targets:
		piece.transform = _originals[piece]
	for light in _light_colors:
		(light as Light3D).light_color = _light_colors[light]
	if _environment:
		_environment.ambient_light_color = _ambient_original
		_environment.fog_light_color = _fog_original
