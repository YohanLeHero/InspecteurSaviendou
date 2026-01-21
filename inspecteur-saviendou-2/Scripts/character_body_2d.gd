extends CharacterBody2D

signal isClicked(name : String)


func _on_mouse_entered() -> void:
	print("0")
	var event : InputEvent
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			print("1")
			isClicked.emit(self.name)
