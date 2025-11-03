extends CharacterBody2D

@export var speed = 400

func getImput():
	var pos = Input.get_axis("Clicked")
	t = input_direction * speed

func _physics_process(delta): 
	getImput()
	move_and_slide()
	
