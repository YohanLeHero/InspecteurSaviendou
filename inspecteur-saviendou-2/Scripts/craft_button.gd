extends Sprite2D

signal buttonClick()

func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event.is_action_pressed("Click"):
		print("oui")
		buttonClick.emit()


func _on_area_2d_mouse_entered() -> void:
	print("oui") # Replace with function body.


func _on_area_2d_mouse_shape_entered(shape_idx: int) -> void:
	print("oui") # Replace with function body.

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Click"):
		print("dqs")
