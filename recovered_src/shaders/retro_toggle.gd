extends CanvasLayer

func _unhandled_input(event: InputEvent) -> void :
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
		visible = not visible
