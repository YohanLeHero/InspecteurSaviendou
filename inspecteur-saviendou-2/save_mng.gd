extends Node2D

@export var path : String

func _ready() -> void:
	print(save.Invetory, "load")
	print(get_tree().get_nodes_in_group("Items"))
	for node in get_tree().get_nodes_in_group("Items"):
		print(node)
		if node.get_InInv() == true:
			$"../Inventory".storeItem(node)

func saving():
	var scene = PackedScene.new()
	var result = scene.pack(self)
	if result == OK:
		var err = ResourceSaver.save(scene, path)
		if err != OK:
			print("sqdsq")

func loading():
	var scene = load(path)
	get_tree().change_scene_to_file(path)
