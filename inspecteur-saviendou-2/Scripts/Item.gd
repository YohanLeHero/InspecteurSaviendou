extends Node2D

var cursor_in : bool
var inInv : bool = false

signal isClicked(node : Node2D)
signal debugInv(item : Node2D)
signal _click_cursor(area : Area2D, event : InputEvent)

@onready var interaction_sound := $interaction

@export_multiline var description : Array[String]


func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event.is_action_pressed("Click"):
		print("bon")
		isClicked.emit(self)
		

func set_InInv(b : bool):
	inInv = b

func get_InInv():
	return inInv

func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.get_parent().name == "HeadTracking": 
		cursor_in = true


func _on_area_2d_area_exited(area: Area2D) -> void:
	if area.get_parent().name == "HeadTracking": 
		cursor_in = false

func get_texture():
	return get_node("Sprite2D").texture 
	
func get_description():
	return description
