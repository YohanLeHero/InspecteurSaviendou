extends Button

func _ready():
	pressed.connect(_on_quit_pressed)

func _on_quit_pressed():
	get_tree().quit()
