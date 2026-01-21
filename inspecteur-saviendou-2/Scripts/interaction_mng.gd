extends Node


var lastCLicked : Node2D
signal sendLastName(node : Node2D)





	


func _on_item_temp_is_clicked(node: Node2D) -> void:
	lastCLicked = node
	sendLastName.emit(lastCLicked)
