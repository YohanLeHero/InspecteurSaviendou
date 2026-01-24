extends CharacterBody2D


@export var questItem : Array[Node2D]
@onready var timeLineCursor : int = 0
signal isClicked(node : Node2D)
signal timeLineAdvenced(dialog : Array[String])

func get_CurrentDialog():
	return $Dialogs.get_children()[timeLineCursor].get_dialog()


func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event.is_action_pressed("Click"):
		isClicked.emit(self)
		if questItem.size() > timeLineCursor:
			print($"../../Interaction_MNG".get_SelectedItem())
			if $"../../Interaction_MNG".get_SelectedItem() == questItem[timeLineCursor]:
				$"../../Inventory/ItemList".remove_item($"../../Inventory".getInvetory().find(questItem[timeLineCursor]))
				forwardTimeLine()

func forwardTimeLine():
	timeLineCursor += 1
	timeLineAdvenced.emit($Dialogs.get_children()[timeLineCursor].get_dialog())
