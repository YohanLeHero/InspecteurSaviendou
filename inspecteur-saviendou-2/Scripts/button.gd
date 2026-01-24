extends Button

signal isPressed()

func _pressed() -> void:
	isPressed.emit()
	print("bonjour")
