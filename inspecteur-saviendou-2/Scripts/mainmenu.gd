extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_start_pressed() -> void:
	print("start pressed")
	get_tree().change_scene_to_file("res://Scene/path_finding.tscn")



func _on_exit_pressed() -> void:
	print("ext pressed")
	get_tree().quit()
	pass # Replace with function body.
