extends CharacterBody2D


const speed = 100.0

@export var footstep_sounds: Array[AudioStream] = []

@export var target: Node2D
@export var inventory : Node2D
@export var cursor : Node2D
@onready var nav_agent := $CollisionShape2D/NavigationAgent2D as NavigationAgent2D
@onready var footstep_player := $FootstepPlayer as AudioStreamPlayer2D
@onready var footstep_timer := $FootstepTimer as Timer

var is_walking := false
var node_clicked : Node2D

signal storeInv(item : Node2D)

func _ready() -> void:
	footstep_timer.timeout.connect(_play_footstep)
	randomize()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Click"):
		#makePath(to_local(cursor.tracker_rect.position)
		makePath(get_local_mouse_position())
		
		node_clicked = null
	#makePath(get_local_mouse_position())

func _physics_process(delta: float) -> void:
	if nav_agent.is_navigation_finished():
		stop_footsteps()
		return
	var current_agent_position: Vector2 = global_position
	#print(dir)
	self.velocity = current_agent_position.direction_to(nav_agent.get_next_path_position()).normalized() * speed 
	move_and_slide()
	start_footsteps()

# --------------------
# FOOTSTEPS
# --------------------

func start_footsteps() -> void:
	if not is_walking:
		is_walking = true
		footstep_timer.start()

func stop_footsteps() -> void:
	if is_walking:
		is_walking = false
		footstep_timer.stop()

func _play_footstep() -> void:
	if not is_walking or footstep_sounds.is_empty():
		return

	footstep_player.stream = footstep_sounds.pick_random()
	footstep_player.pitch_scale = randf_range(0.95, 1.05) # naturel
	footstep_player.play()

# --------------------

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
