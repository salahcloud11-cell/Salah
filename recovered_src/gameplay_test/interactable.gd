class_name Interactable
extends StaticBody3D




enum Decision{SLEEP, LEAVE}

signal activated(interactable: Interactable)

@export var prompt: String = "E - Interact"
@export var decision: Decision = Decision.SLEEP


func interact() -> void :
	activated.emit(self)
