extends Node2D


var inventory : Array
@export var ui_Inventory : ItemList
signal item_got(item : Node2D)
signal node_clicked(node : Node2D)

func storeItem(item : Node2D):
	item_got.emit(item)
	if item.interaction_sound:
		item.interaction_sound.play()
	inventory.push_back(item)
	item.set_InInv(true)
	ui_Inventory.add_item("", item.get_texture())
	await item.interaction_sound.finished


func getInvetory():
	return inventory

func setInventory(Inv : Array):
	inventory = Inv


func _on_player_store_inv(item: Node2D) -> void:
	storeItem(item)


func _on_item_temp_debug_inv(item: Node2D) -> void:
	storeItem(item)


func _on_craft_menu_crafted(CraftSlot: Array) -> void:
	for i in range(CraftSlot.size()):
		self.get_node("ItemList").remove_item(inventory.find(CraftSlot[i]))
		print(CraftSlot[i], "itme")
		if(CraftSlot[i] != null):
			CraftSlot[i].set_InInv(false)
		inventory.erase(CraftSlot[i])
	storeItem(CraftSlot[3])


func _on_item_list_gui_input(event: InputEvent) -> void:
	if(event.is_action_pressed("Click")):
		node_clicked.emit(self)
