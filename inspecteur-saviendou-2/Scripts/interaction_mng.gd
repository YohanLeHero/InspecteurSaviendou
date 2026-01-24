extends Node


var lastCLicked : Node2D
var selectedItem : Node2D
signal sendLastName(node : Node2D)





	


func _on_item_temp_is_clicked(node: Node2D) -> void:
	lastCLicked = node
	sendLastName.emit(lastCLicked)


func _on_item_list_item_selected(index: int) -> void:
	print($"../Inventory".getInvetory()[index])
	selectedItem = $"../Inventory".getInvetory()[index]
	

func get_SelectedItem():
	return selectedItem
