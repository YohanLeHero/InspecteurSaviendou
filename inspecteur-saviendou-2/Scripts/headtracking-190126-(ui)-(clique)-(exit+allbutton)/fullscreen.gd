extends Button

@export var tracker_node: Node2D
@export var hide_cursor: bool = true

# On retient la taille de la fenêtre avant fullscreen
var previous_window_size: Vector2

func _ready():
	focus_mode = FocusMode.FOCUS_NONE
	previous_window_size = DisplayServer.window_get_size()
	update_text()

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggle_fullscreen()

func toggle_fullscreen():
	var current_mode = DisplayServer.window_get_mode()

	# Bascule plein écran <-> fenêtre
	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(previous_window_size)
	else:
		# Sauvegarde la taille actuelle avant de passer fullscreen
		previous_window_size = DisplayServer.window_get_size()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	# Attendre un frame pour que la fenêtre soit redimensionnée
	await get_tree().process_frame

	# Recentrer le tracker
	if tracker_node:
		var vp = get_viewport().get_visible_rect().size
		Globals.screen_size = vp
		Globals.screen_center = vp / 2
		Globals.screen_pos = Globals.screen_center
		Globals.target_screen_pos = Globals.screen_center
		tracker_node.position = Globals.screen_center

	# Curseur selon hide_cursor
	if hide_cursor:
		Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED_HIDDEN)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)

	update_text()

func update_text():
	var m = DisplayServer.window_get_mode()
	if m == DisplayServer.WINDOW_MODE_FULLSCREEN:
		text = "Sortir du plein écran"
	else:
		text = "Plein écran"
