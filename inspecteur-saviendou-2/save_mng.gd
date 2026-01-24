extends Node2D

@export var path : String

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
