extends Node3D




@onready var manager: AnomalyManager = $AnomalyManager
@onready var debug_label: Label = $CanvasLayer / DebugLabel


func _ready() -> void :

	manager.generate_round()


func _process(_delta: float) -> void :
	_update_debug_label()


func _unhandled_input(event: InputEvent) -> void :
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_G:
				manager.generate_round()
			KEY_R:
				manager.reset_round()
			KEY_N:

				manager.generate_round(true)
			KEY_A:

				manager.generate_round(false, true)


func _update_debug_label() -> void :
	var object_name: String = "---"
	if manager.selected_object != null:
		object_name = manager.selected_object.name
	debug_label.text = """Anomaly System Test
""" + "G = Generate Round   R = Reset Normal\n"\
	+ "N = Force Normal   A = Force Anomaly\n"\
	+ "WASD Move / Shift Sprint / Space Jump\n\n"\
	+ "Round: %d\n" % manager.round_number\
	+ "Has Anomaly: %s\n" % ("YES" if manager.has_anomaly else "NO")\
	+ "Selected Object: %s\n" % object_name\
	+ "Selected Variant: %s\n" % (manager.selected_variant_name if manager.has_anomaly else "---")
