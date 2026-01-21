extends CharacterBody2D



const speed = 50

@export var target: Node2D
@onready var nav_agent := $NavigationAgent2D as NavigationAgent2D

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			makePath(get_local_mouse_position())

func _physics_process(delta: float) -> void:
	
	if nav_agent.is_navigation_finished():
		return
	var current_agent_position: Vector2 = global_position
	#print(dir)
	velocity = current_agent_position.direction_to(nav_agent.get_next_path_position()).normalized() * speed
	move_and_slide()
	
func makePath(clickPos) -> void:
	nav_agent.set_target_position(to_global(clickPos))
