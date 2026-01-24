extends HBoxContainer

var craftSlot = [null, null, null, null] 

signal Crafted(CraftSlot : Array)

func _on_button_pressed() -> void:
	visible = !is_visible_in_tree()


func _on_item_list_item_selected(index: int) -> void:
	if is_visible_in_tree():
		var invetory = $"../../Inventory".getInvetory()
		if craftSlot[0] == null:
			for i in range(craftSlot.size()):
				if invetory[index] == craftSlot[i]:
					return
			craftSlot[0] = invetory[index]
			self.get_node("Slot1").set_button_icon(invetory[index].get_texture())
		elif  craftSlot[1] == null:
			for i in range(craftSlot.size()):
				if invetory[index] == craftSlot[i]:
					return
			craftSlot[1] = invetory[index]
			self.get_node("Slot2").set_button_icon(invetory[index].get_texture())
		elif  craftSlot[2] == null:
			for i in range(craftSlot.size()):
				if invetory[index] == craftSlot[i]:
					return
			craftSlot[2] = invetory[index]
			self.get_node("Slot3").set_button_icon(invetory[index].get_texture())
	craft()

func craft():
	var recipes = %"RecipesList".get_children()
	for i in range(recipes.size()):
		if recipes[i].getItem1() == craftSlot[0] or recipes[i].getItem1() == craftSlot[1] or recipes[i].getItem1() == craftSlot[2]:
			if recipes[i].getItem2() == craftSlot[0] or recipes[i].getItem2() == craftSlot[1] or recipes[i].getItem2() == craftSlot[2]:
				if recipes[i].getItem3() == craftSlot[0] or recipes[i].getItem3() == craftSlot[1] or recipes[i].getItem3() == craftSlot[2]:
					craftSlot[3] = recipes[i].getResult()
					self.get_node("Result").set_button_icon(recipes[i].getResult().get_texture())
					return
		craftSlot[3] = null
		self.get_node("Result").set_button_icon(null)

func _on_slot_1_pressed() -> void:
	if self.get_node("Slot1").get_button_icon() != null:
		self.get_node("Slot1").set_button_icon(null)
		craftSlot[0] = null
		craft()


func _on_slot_2_pressed() -> void:
	if self.get_node("Slot2").get_button_icon() != null:
		self.get_node("Slot2").set_button_icon(null)
		craftSlot[1] = null
		craft()


func _on_slot_3_pressed() -> void:
	if self.get_node("Slot3").get_button_icon() != null:
		self.get_node("Slot3").set_button_icon(null)
		craftSlot[2] = null
		craft()


func _on_result_pressed() -> void:
	if self.get_node("Result").get_button_icon() != null:
		Crafted.emit(craftSlot)
		self.get_node("Slot1").set_button_icon(null)
		self.get_node("Slot2").set_button_icon(null)
		self.get_node("Slot3").set_button_icon(null)
		self.get_node("Result").set_button_icon(null)
		for i in range(craftSlot.size()):
			craftSlot[i] = null
