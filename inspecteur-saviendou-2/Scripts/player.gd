extends CharacterBody2D


const speed = 100.0

@export var target: Node2D
@export var inventory : Node2D
@export var cursor : Node2D
@onready var nav_agent := $CollisionShape2D/NavigationAgent2D as NavigationAgent2D
var node_clicked : Node2D

signal storeInv(item : Node2D)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Click"):
		#makePath(to_local(cursor.tracker_rect.position)
		makePath(get_local_mouse_position())
		
		node_clicked = null
	#makePath(get_local_mouse_position())

func _physics_process(delta: float) -> void:
	if nav_agent.is_navigation_finished():
		return
	var current_agent_position: Vector2 = global_position
	#print(dir)
	self.velocity = current_agent_position.direction_to(nav_agent.get_next_path_position()).normalized() * speed 
	move_and_slide()
	
func makePath(clickPos) -> void:
	nav_agent.set_target_position(to_global(clickPos))
	
	


func _on_item_box_body_entered(body: Node2D) -> void:
	print("oui")
	if body.is_in_group("Items") and node_clicked == body: 
		storeInv.emit(node_clicked)
		body.visible = false

func _on_interaction_mng_send_last_name(node: Node2D) -> void:
	node_clicked = node
	print(node.name)
