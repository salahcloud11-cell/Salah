class_name AnomalyObject
extends Node3D















const GROUP: = "anomaly_objects"



const DIFFICULTY_META: = "zdifficulty"

enum Difficulty{EASY = 1, MEDIUM = 2, HARD = 3}

@onready var variants: Node3D = get_node_or_null("Variants")

func _enter_tree() -> void :
	add_to_group(GROUP)

func _ready() -> void :
	if variants == null:
		push_warning("[AnomalyObject] '%s' is missing a 'Variants' child node." % name)
	elif variants.get_child_count() == 0:
		push_warning("[AnomalyObject] '%s' Variants node is empty. Add at least a 'Normal' child." % name)



func get_anomaly_variant_count() -> int:
	if variants == null:
		return 0
	return maxi(variants.get_child_count() - 1, 0)



func has_anomaly_variants() -> bool:
	return get_anomaly_variant_count() > 0






func activate_variant(index: int) -> void :
	if variants == null:
		push_warning("[AnomalyObject] '%s' cannot activate variant %d: no 'Variants' node." % [name, index])
		return
	var count: = variants.get_child_count()
	if count == 0:
		push_warning("[AnomalyObject] '%s' cannot activate variant %d: Variants is empty." % [name, index])
		return
	if index < 0 or index >= count:
		push_warning("[AnomalyObject] '%s' variant index %d out of range [0, %d]." % [name, index, count - 1])
		return
	for i in count:
		var variant_node: = variants.get_child(i)
		variant_node.visible = (i == index)
		_set_variant_collisions_enabled(variant_node, i == index)




func _set_variant_collisions_enabled(variant_node: Node, enabled: bool) -> void :
	for col in variant_node.find_children("*", "CollisionShape3D", true, false):
		if col is CollisionShape3D:
			col.set_deferred("disabled", not enabled)



func reset_to_normal() -> void :
	activate_variant(0)





func activate_random_anomaly(rng: RandomNumberGenerator, max_difficulty: int = Difficulty.HARD) -> bool:
	var eligible: = get_variant_indices_within_difficulty(max_difficulty)
	if eligible.is_empty():
		return false
	activate_variant(eligible[rng.randi_range(0, eligible.size() - 1)])
	return true




func get_variant_difficulty(index: int) -> int:
	if variants == null or index < 0 or index >= variants.get_child_count():
		return Difficulty.EASY
	var variant_node: Node = variants.get_child(index)
	if variant_node.has_meta(DIFFICULTY_META):
		return clampi(int(variant_node.get_meta(DIFFICULTY_META)), Difficulty.EASY, Difficulty.HARD)
	return Difficulty.EASY



func get_variant_indices_within_difficulty(max_difficulty: int) -> Array[int]:
	var result: Array[int] = []
	if variants == null:
		return result
	for i in range(1, variants.get_child_count()):
		if get_variant_difficulty(i) <= max_difficulty:
			result.append(i)
	return result



func has_variant_within_difficulty(max_difficulty: int) -> bool:
	return not get_variant_indices_within_difficulty(max_difficulty).is_empty()



func get_active_variant_index() -> int:
	if variants == null:
		return -1
	for i in variants.get_child_count():
		if variants.get_child(i).visible:
			return i
	return -1



func get_variant_name(index: int) -> String:
	if variants == null or index < 0 or index >= variants.get_child_count():
		return ""
	return variants.get_child(index).name
