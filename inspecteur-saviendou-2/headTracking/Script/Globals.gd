# Globals.gd 
extends Node
 # === CONNECTION SETTINGS ===
const PORT = 4242
 # === HEAD TRACKING SETTINGS === 
var raw_x = 0.0 
var raw_y = 0.0 
var raw_roll = 0.0 
var screen_pos = Vector2.ZERO 
var target_screen_pos = Vector2.ZERO 
# Réglages 
var x_offset = 0.0
var y_offset = 0.0 
var x_gain = 1.0 
var y_gain = 1.0 
var invert_x = false 
var invert_y = false
var smoothing = 1.5 
var prediction = 0.2 
var deadzone = 0.02 

# Détection de clic par RECUL 
var click_backward_threshold = 0.5 
var backward_hold_time = 0.0 
const BACKWARD_HOLD_THRESHOLD = 0.3 
var max_backward_detected = 0.0 
var backward_axis_index = 5 
var backward_invert = false 
# Cooldowns séparés 
var head_tracking_cooldown = 0.5
var controller_cooldown = 0.3 
var mouse_cooldown = 0.2 
# Derniers clics 
var last_head_tracking_click = 0.0 
var last_controller_click = 0.0 
var last_mouse_click = 0.0 
# Modes de contrôle 
var current_mode = 2 
# 0 = head tracking, 1 = manette, 2 = souris 
var controller_speed = 500.0 
var controller_deadzone = 0.2 
var mouse_speed = 1.0 
var mouse_sensitivity = 1.0 
# Écran 
var screen_size = Vector2.ZERO 
var screen_center = Vector2.ZERO 
var margin = 50 
# Buffer 
var buffer_x = [] 
var buffer_y = [] 
const BUFFER_SIZE = 5 
# Filtre 
var filtered_x = 0.0 
var filtered_y = 0.0 
var filtered_backward = 0.0 
var last_filtered_x = 0.0 
var last_filtered_y = 0.0 
const FILTER_STRENGTH = 0.3 
# Vitesse 
var velocity_x = 0.0 
var velocity_y = 0.0 
var last_raw_x = 0.0 
var last_raw_y = 0.0 
# Debug 
var all_axes = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0] 
# Variables souris
var mouse_motion = Vector2.ZERO 
var mouse_accumulated = Vector2.ZERO 
var mouse_position = Vector2.ZERO 
var mouse_cursor_visible = true 
# Interface 
var show_debug_interface = false 
# Boutons manette (pour référence) 
var controller_a_pressed = false 
var controller_b_pressed = false 
var controller_x_pressed = false 
var controller_y_pressed = false 
var controller_lb_pressed = false 
var controller_rb_pressed = false 
var controller_back_pressed = false 
var controller_start_pressed = false 
var controller_left_stick_pressed = false 
var controller_right_stick_pressed = false 
# Sauvegarde/Lecture des paramètres 
const SETTINGS_FILE = "user://eye_tracking_settings.cfg" 
func _ready(): 
	# Charger les paramètres au démarrage 
	load_settings() 
func save_settings(): 
	var config = ConfigFile.new() 
# Head Tracking Settings 
	config.set_value("head_tracking", "x_offset", x_offset)
	config.set_value("head_tracking", "y_offset", y_offset)
	config.set_value("head_tracking", "x_gain", x_gain)
	config.set_value("head_tracking", "y_gain", y_gain)
	config.set_value("head_tracking", "invert_x", invert_x)
	config.set_value("head_tracking", "invert_y", invert_y) 
	config.set_value("head_tracking", "smoothing", smoothing) 
	config.set_value("head_tracking", "prediction", prediction)
	config.set_value("head_tracking", "deadzone", deadzone) 

	# Click Settings 
	config.set_value("click", "click_backward_threshold", click_backward_threshold)
	config.set_value("click", "backward_axis_index", backward_axis_index) 
	config.set_value("click", "backward_invert", backward_invert) 

	# Co<oldowns
	config.set_value("cooldowns", "head_tracking_cooldown", head_tracking_cooldown)
	config.set_value("cooldowns", "controller_cooldown", controller_cooldown) 
	config.set_value("cooldowns", "mouse_cooldown", mouse_cooldown) 

	# Controller Settings 
	config.set_value("controller", "controller_speed", controller_speed) 
	config.set_value("controller", "controller_deadzone", controller_deadzone) 

	# Mouse Settings 
	config.set_value("mouse", "mouse_speed", mouse_speed) 
	config.set_value("mouse", "mouse_sensitivity", mouse_sensitivity) 

	# Mode 
	config.set_value("mode", "current_mode", current_mode) 
	# Screen
	config.set_value("screen", "margin", margin) 
	# Save to file 
	var err = config.save(SETTINGS_FILE) 
	if err == OK: 
		print("Paramètres sauvegardés avec succès") 
	else: 
		print("Erreur lors de la sauvegarde des paramètres: ", err) 

func load_settings(): 
	var config = ConfigFile.new() 
	var err = config.load(SETTINGS_FILE) 
	if err == OK: 
		# Head Tracking Settings 
		x_offset = config.get_value("head_tracking", "x_offset", x_offset)
		y_offset = config.get_value("head_tracking", "y_offset", y_offset) 
		x_gain = config.get_value("head_tracking", "x_gain", x_gain) 
		y_gain = config.get_value("head_tracking", "y_gain", y_gain) 
		invert_x = config.get_value("head_tracking", "invert_x", invert_x) 
		invert_y = config.get_value("head_tracking", "invert_y", invert_y) 
		smoothing = config.get_value("head_tracking", "smoothing", smoothing) 
		prediction = config.get_value("head_tracking", "prediction", prediction) 
		deadzone = config.get_value("head_tracking", "deadzone", deadzone) 
		
		# Click Settings
		click_backward_threshold = config.get_value("click", "click_backward_threshold", click_backward_threshold)
		backward_axis_index = config.get_value("click", "backward_axis_index", backward_axis_index)
		backward_invert = config.get_value("click", "backward_invert", backward_invert)
		
		 # Cooldowns
		head_tracking_cooldown = config.get_value("cooldowns", "head_tracking_cooldown", head_tracking_cooldown)
		controller_cooldown = config.get_value("cooldowns", "controller_cooldown", controller_cooldown)
		mouse_cooldown = config.get_value("cooldowns", "mouse_cooldown", mouse_cooldown)
		
		 # Controller Settings
		controller_speed = config.get_value("controller", "controller_speed", controller_speed)
		controller_deadzone = config.get_value("controller", "controller_deadzone", controller_deadzone)
		# Mouse Settings 
		mouse_speed = config.get_value("mouse", "mouse_speed", mouse_speed) 
		mouse_sensitivity = config.get_value("mouse", "mouse_sensitivity", mouse_sensitivity)
		
		 # Mode 
		current_mode = config.get_value("mode", "current_mode", current_mode) 
		
		 # Screen 
		margin = config.get_value("screen", "margin", margin)
		print("Paramètres chargés avec succès") 
		
	else:
		print("Chargement des paramètres par défaut (fichier non trouvé)") 
	
	
func reset_to_default(): 
	# Reset all variables to default values 
	x_offset = 0.0 
	y_offset = 0.0 
	x_gain = 1.0 
	y_gain = 1.0 
	invert_x = false 
	invert_y = false 
	smoothing = 1.5
	prediction = 0.2 
	deadzone = 0.02 
	click_backward_threshold = 0.5 
	backward_axis_index = 5 
	backward_invert = false 
	head_tracking_cooldown = 0.5 
	controller_cooldown = 0.3 
	mouse_cooldown = 0.2 
	controller_speed = 500.0 
	controller_deadzone = 0.2 
	mouse_speed = 1.0 
	mouse_sensitivity = 1.0 
	current_mode = 0 
	margin = 50 
	print("Paramètres réinitialisés aux valeurs par défaut")
