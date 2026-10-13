class_name AnomalyManager
extends Node







@export_range(0.0, 1.0) var anomaly_chance: float = 0.65

const GROUP: = "anomaly_objects"



var difficulty_level: int = AnomalyObject.Difficulty.HARD

var _rng: = RandomNumberGenerator.new()

var round_number: int = 0
var has_anomaly: bool = false
var selected_object: AnomalyObject = null
var selected_variant_index: int = -1
var selected_variant_name: String = ""


func _ready() -> void :
	_rng.randomize()



func set_difficulty(level: int) -> void :
	difficulty_level = clampi(level, AnomalyObject.Difficulty.EASY, AnomalyObject.Difficulty.HARD)










func generate_round(force_normal: bool = false, force_anomaly: bool = false) -> void :
	round_number += 1
	_clear_selection()

	reset_round()

	if force_normal or ( not force_anomaly and _rng.randf() >= anomaly_chance):
		_emit_round_log()
		return

	var eligible: = _get_eligible_objects()
	if eligible.is_empty():
		push_warning("[AnomalyManager] Forced anomaly but no object has an anomaly variant within difficulty %d. Round is NORMAL." % difficulty_level)
		_emit_round_log()
		return

	selected_object = eligible[_rng.randi_range(0, eligible.size() - 1)]
	if selected_object.activate_random_anomaly(_rng, difficulty_level):
		has_anomaly = true
		selected_variant_index = selected_object.get_active_variant_index()
		selected_variant_name = selected_object.get_variant_name(selected_variant_index)
	else:
		selected_object = null

	_emit_round_log()



func reset_round() -> void :
	_clear_selection()
	for node in get_tree().get_nodes_in_group(GROUP):
		if node is AnomalyObject:
			node.reset_to_normal()


func is_current_round_anomalous() -> bool:
	return has_anomaly



func _get_eligible_objects() -> Array[AnomalyObject]:
	var result: Array[AnomalyObject] = []
	for node in get_tree().get_nodes_in_group(GROUP):
		if node is AnomalyObject and node.has_anomaly_variants() and node.has_variant_within_difficulty(difficulty_level):
			result.append(node)
	return result


func _clear_selection() -> void :
	has_anomaly = false
	selected_object = null
	selected_variant_index = -1
	selected_variant_name = ""


func _emit_round_log() -> void :
	if has_anomaly and selected_object != null:
		print("[AnomalyManager] Round %d generated: ANOMALY | Object: %s | Variant: %s"\
		%[round_number, selected_object.name, selected_variant_name])
	else:
		print("[AnomalyManager] Round %d generated: NORMAL" % round_number)
