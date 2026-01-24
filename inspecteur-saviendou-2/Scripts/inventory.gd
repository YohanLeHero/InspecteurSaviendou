extends Node2D


var inventory : Array
@export var ui_Inventory : ItemList

func storeItem(item : Node2D):
	if item.interaction_sound:
		item.interaction_sound.play()
	inventory.push_back(item)
	ui_Inventory.add_item("", item.get_texture())
	await item.interaction_sound.finished


func getInvetory():
	return inventory


func _on_player_store_inv(item: Node2D) -> void:
	storeItem(item)


func _on_item_temp_debug_inv(item: Node2D) -> void:
	storeItem(item)


func _on_craft_menu_crafted(CraftSlot: Array) -> void:
	for i in range(CraftSlot.size()):
		self.get_node("ItemList").remove_item(inventory.find(CraftSlot[i]))
		inventory.erase(CraftSlot[i])
	inventory.push_back(CraftSlot[3])
	ui_Inventory.add_item("", CraftSlot[3].get_texture())
