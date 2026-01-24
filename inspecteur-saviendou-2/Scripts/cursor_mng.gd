extends Node2D

@export var cursor : Node2D

func _process(delta: float) -> void:
	Input.warp_mouse(cursor.tracker_rect.position)
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Click"):
		Input
