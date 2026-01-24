extends Node2D

# Déclaration de Globals
var Globals

signal left_click

@onready var tracker_rect = $TrackerRect
@onready var debug_label = $ScrollContainer/Label
@onready var scroll_container = $ScrollContainer

var udp := PacketPeerUDP.new()



func _ready():
	# Initialiser Globals
	init_globals()
	# Empêche la souris de sortir de la fenêtre
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED_HIDDEN)





	print("EYE TRACKING - MULTIMODE AVEC COOLDOWNS SÉPARÉS")
	
	# Initialiser les variables d'écran
	Globals.screen_size = get_viewport().get_visible_rect().size
	Globals.screen_center = Globals.screen_size / 2
	Globals.screen_pos = Globals.screen_center
	Globals.target_screen_pos = Globals.screen_center
	Globals.mouse_position = Globals.screen_center
	
	tracker_rect.position = Globals.screen_center
	tracker_rect.modulate = Color.GREEN
	tracker_rect.scale = Vector2(0.3, 0.3)
	
	

	# Cacher le curseur de la souris
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED_HIDDEN)

	
	if udp.bind(Globals.PORT) == OK:
		print("Connecté au port", Globals.PORT)
		
	else:
		debug_label.text = "Erreur de connexion"

func init_globals():
	# Créer Globals s'il n'existe pas
	if not has_node("/root/Globals"):
		var globals_script = load("res://Globals.gd")
		Globals = globals_script.new()
		Globals.name = "Globals"
		
		print("Globals créé manuellement")
	else:
		Globals = get_node("/root/Globals")
		print("Globals trouvé")

func _process(delta):
	match Globals.current_mode:
		0:
			process_head_tracking(delta)
		1:
			process_controller(delta)
		2:
			process_mouse(delta)
			
		# ===============================
	# Confinement du curseur
	# ===============================
	Globals.screen_pos.x = clamp(Globals.screen_pos.x, Globals.margin, Globals.screen_size.x - Globals.margin)
	Globals.screen_pos.y = clamp(Globals.screen_pos.y, Globals.margin, Globals.screen_size.y - Globals.margin)
	tracker_rect.position = Globals.screen_pos
	

	update_display()

func process_head_tracking(delta):
	var packets_processed = 0
	
	while udp.get_available_packet_count() > 0:
		var packet = udp.get_packet()
		
		if packet.size() >= 24:
			Globals.raw_x = packet.decode_float(4)
			Globals.raw_y = packet.decode_float(12)
			
			for i in range(0, min(6, round(packet.size()) / 4)):
				Globals.all_axes[i] = packet.decode_float(i * 4)
			
			Globals.raw_roll = Globals.all_axes[Globals.backward_axis_index]
			
			packets_processed += 1
			
			Globals.velocity_x = Globals.raw_x - Globals.last_raw_x
			Globals.velocity_y = Globals.raw_y - Globals.last_raw_y
			Globals.last_raw_x = Globals.raw_x
			Globals.last_raw_y = Globals.raw_y
			
			Globals.buffer_x.push_back(Globals.raw_x)
			Globals.buffer_y.push_back(Globals.raw_y)
			
			if Globals.buffer_x.size() > Globals.BUFFER_SIZE:
				Globals.buffer_x.pop_front()
			if Globals.buffer_y.size() > Globals.BUFFER_SIZE:
				Globals.buffer_y.pop_front()
	
	if packets_processed > 0:
		var weighted_x = 0.0
		var weighted_y = 0.0
		var total_weight = 0.0
		
		for i in range(Globals.buffer_x.size()):
			var weight = (i + 1) / float(Globals.buffer_x.size())
			weighted_x += Globals.buffer_x[i] * weight
			weighted_y += Globals.buffer_y[i] * weight
			total_weight += weight
		
		if total_weight > 0:
			weighted_x /= total_weight
			weighted_y /= total_weight
		
		Globals.last_filtered_x = Globals.filtered_x
		Globals.last_filtered_y = Globals.filtered_y
		
		Globals.filtered_x = Globals.filtered_x * (1.0 - Globals.FILTER_STRENGTH) + weighted_x * Globals.FILTER_STRENGTH
		Globals.filtered_y = Globals.filtered_y * (1.0 - Globals.FILTER_STRENGTH) + weighted_y * Globals.FILTER_STRENGTH
		Globals.filtered_backward = Globals.filtered_backward * (1.0 - Globals.FILTER_STRENGTH) + Globals.raw_roll * Globals.FILTER_STRENGTH
		
		var adjusted_x = (Globals.filtered_x + Globals.x_offset) * Globals.x_gain
		var adjusted_y = (Globals.filtered_y + Globals.y_offset) * Globals.y_gain
		
		if Globals.invert_x:
			adjusted_x = -adjusted_x
		if Globals.invert_y:
			adjusted_y = -adjusted_y
		
		if abs(adjusted_x) < Globals.deadzone:
			adjusted_x = 0.0
		if abs(adjusted_y) < Globals.deadzone:
			adjusted_y = 0.0
		
		adjusted_x = clamp(adjusted_x, -1.0, 1.0)
		adjusted_y = clamp(adjusted_y, -1.0, 1.0)
		
		detect_backward_for_click(delta)
		
		Globals.target_screen_pos = Vector2(
			remap(adjusted_x, -1.0, 1.0, Globals.margin, Globals.screen_size.x - Globals.margin),
			remap(adjusted_y, -1.0, 1.0, Globals.margin, Globals.screen_size.y - Globals.margin)
		)
	
	if packets_processed > 0:
		var predicted_x = Globals.velocity_x * Globals.prediction * 100
		var predicted_y = Globals.velocity_y * Globals.prediction * 100
		
		Globals.target_screen_pos.x += predicted_x
		Globals.target_screen_pos.y += predicted_y
	
	var distance = Globals.screen_pos.distance_to(Globals.target_screen_pos)
	var adaptive_smoothing = Globals.smoothing
	
	if distance < 10:
		adaptive_smoothing = Globals.smoothing * 0.8
	elif distance > 100:
		adaptive_smoothing = Globals.smoothing * 1.2
	
	var t = adaptive_smoothing * (1.0 - exp(-delta * 10.0))
	Globals.screen_pos = Globals.screen_pos.lerp(Globals.target_screen_pos, t)
	
	tracker_rect.position = Globals.screen_pos

func process_controller(delta):
	var left_stick_x = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var left_stick_y = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	
	if abs(left_stick_x) < Globals.controller_deadzone:
		left_stick_x = 0.0
	if abs(left_stick_y) < Globals.controller_deadzone:
		left_stick_y = 0.0
	
	var move_x = left_stick_x * Globals.controller_speed * delta
	var move_y = left_stick_y * Globals.controller_speed * delta
	
	Globals.target_screen_pos.x += move_x
	Globals.target_screen_pos.y += move_y
	
	Globals.target_screen_pos.x = clamp(Globals.target_screen_pos.x, Globals.margin, Globals.screen_size.x - Globals.margin)
	Globals.target_screen_pos.y = clamp(Globals.target_screen_pos.y, Globals.margin, Globals.screen_size.y - Globals.margin)
	
	var t = Globals.smoothing * (1.0 - exp(-delta * 10.0))
	Globals.screen_pos = Globals.screen_pos.lerp(Globals.target_screen_pos, t)
	
	tracker_rect.position = Globals.screen_pos
	
	detect_controller_buttons(delta)

func process_mouse(delta):
	var move_x = Globals.mouse_motion.x * Globals.mouse_speed * Globals.mouse_sensitivity
	var move_y = Globals.mouse_motion.y * Globals.mouse_speed * Globals.mouse_sensitivity
	
	Globals.mouse_accumulated.x += move_x
	Globals.mouse_accumulated.y += move_y
	
	if abs(Globals.mouse_accumulated.x) >= 1.0:
		Globals.target_screen_pos.x += int(Globals.mouse_accumulated.x)
		Globals.mouse_accumulated.x -= int(Globals.mouse_accumulated.x)
	
	if abs(Globals.mouse_accumulated.y) >= 1.0:
		Globals.target_screen_pos.y += int(Globals.mouse_accumulated.y)
		Globals.mouse_accumulated.y -= int(Globals.mouse_accumulated.y)
	
	Globals.target_screen_pos.x = clamp(Globals.target_screen_pos.x, Globals.margin, Globals.screen_size.x - Globals.margin)
	Globals.target_screen_pos.y = clamp(Globals.target_screen_pos.y, Globals.margin, Globals.screen_size.y - Globals.margin)
	
	var t = Globals.smoothing * (1.0 - exp(-delta * 10.0))
	Globals.screen_pos = Globals.screen_pos.lerp(Globals.target_screen_pos, t)
	
	tracker_rect.position = Globals.screen_pos
	
	Globals.mouse_motion = Vector2.ZERO
	
	detect_mouse_clicks(delta)

func detect_backward_for_click(delta):
	var current_time = Time.get_ticks_msec() / 1000.0
	var time_since_last_click = current_time - Globals.last_head_tracking_click
	
	var backward_value = Globals.filtered_backward
	if Globals.backward_invert:
		backward_value = -backward_value
	
	if abs(backward_value) > abs(Globals.max_backward_detected):
		Globals.max_backward_detected = backward_value
	
	if backward_value > Globals.click_backward_threshold:
		Globals.backward_hold_time += delta
		
		if Globals.backward_hold_time >= Globals.BACKWARD_HOLD_THRESHOLD and time_since_last_click > Globals.head_tracking_cooldown:
			trigger_click(0)
			Globals.backward_hold_time = 0.0
			Globals.last_head_tracking_click = current_time
	else:
		Globals.backward_hold_time = 0.0

func detect_controller_buttons(_delta):
	var current_time = Time.get_ticks_msec() / 1000.0
	var time_since_last_click = current_time - Globals.last_controller_click
	
	if Input.is_joy_button_pressed(0, JOY_BUTTON_A):
		if time_since_last_click > Globals.controller_cooldown:
			trigger_click(1)
			Globals.last_controller_click = current_time
	
	if Input.is_joy_button_pressed(0, JOY_BUTTON_B):
		Globals.screen_pos = Globals.screen_center
		Globals.target_screen_pos = Globals.screen_center
		tracker_rect.position = Globals.screen_center
	
	if Input.is_joy_button_pressed(0, JOY_BUTTON_X):
		Globals.controller_speed += 50.0
		Globals.controller_speed = min(Globals.controller_speed, 2000.0)
	
	if Input.is_joy_button_pressed(0, JOY_BUTTON_Y):
		Globals.controller_speed -= 50.0
		Globals.controller_speed = max(Globals.controller_speed, 50.0)
	
	if Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER):
		Globals.x_gain += 0.1
		print("X gain:", Globals.x_gain)
	
	if Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_SHOULDER):
		Globals.x_gain = max(0.1, Globals.x_gain - 0.1)
		print("X gain:", Globals.x_gain)

func detect_mouse_clicks(_delta):
	var current_time = Time.get_ticks_msec() / 1000.0
	var time_since_last_click = current_time - Globals.last_mouse_click
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if time_since_last_click > Globals.mouse_cooldown:
			trigger_click(2)
			Globals.last_mouse_click = current_time
			
			
			
			
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		Globals.screen_pos = Globals.screen_center
		Globals.target_screen_pos = Globals.screen_center
		tracker_rect.position = Globals.screen_center
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_WHEEL_UP):
		Globals.mouse_speed += 0.1
		Globals.mouse_speed = min(Globals.mouse_speed, 5.0)
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_WHEEL_DOWN):
		Globals.mouse_speed -= 0.1
		Globals.mouse_speed = max(Globals.mouse_speed, 0.1)

func trigger_click(mode_index):
	send_real_left_click()
	left_click.emit() # optionnel, pour tes propres scripts

	var mode_str = ""
	match mode_index:
		0: mode_str = "HEAD TRACKING"
		1: mode_str = "MANETTE"
		2: mode_str = "SOURIS"
	
	print("=== CLIC (" + mode_str + ") ===")
	print("Position curseur: ", tracker_rect.position)
	print("Temps: ", Time.get_time_string_from_system())
	print("===================")
	
	
	tracker_rect.modulate = Color(1, 0.5, 0)
	
	var timer = get_tree().create_timer(0.2)
	timer.timeout.connect(func():
		match Globals.current_mode:
			0: tracker_rect.modulate = Color.GREEN
			1: tracker_rect.modulate = Color.CYAN
			2: tracker_rect.modulate = Color.YELLOW
	)

func _input(event):
	
	
		
	if Globals.current_mode == 2 and event is InputEventMouseMotion:
		Globals.mouse_motion = event.relative
	
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F1:
				# Basculer l'affichage de l'interface de débogage
				Globals.show_debug_interface = !Globals.show_debug_interface
				scroll_container.visible = Globals.show_debug_interface
				print("Interface debug: ", "ON" if Globals.show_debug_interface else "OFF")
			
			KEY_M:
				Globals.current_mode = (Globals.current_mode + 1) % 3
				var mode_names = ["HEAD TRACKING", "MANETTE", "SOURIS"]
				print("Mode changé: ", mode_names[Globals.current_mode])
				
				match Globals.current_mode:
					0: tracker_rect.modulate = Color.GREEN
					1: tracker_rect.modulate = Color.CYAN
					2: tracker_rect.modulate = Color.YELLOW
				
				if Globals.current_mode == 2:
					Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				else:
					Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
			
			KEY_LEFT:
				if Globals.current_mode == 0:
					Globals.x_offset -= 0.1
					print("X offset:", Globals.x_offset)
					Globals.save_settings()
			
			KEY_RIGHT:
				if Globals.current_mode == 0:
					Globals.x_offset += 0.1
					print("X offset:", Globals.x_offset)
					Globals.save_settings()
			
			KEY_UP:
				if Globals.current_mode == 0:
					Globals.y_offset -= 0.1
					print("Y offset:", Globals.y_offset)
					Globals.save_settings()
			
			KEY_DOWN:
				if Globals.current_mode == 0:
					Globals.y_offset += 0.1
					print("Y offset:", Globals.y_offset)
					Globals.save_settings()
			
			KEY_A:
				if Globals.current_mode == 0:
					Globals.x_gain += 0.1
					print("X gain:", Globals.x_gain)
					Globals.save_settings()
			
			KEY_Z:
				if Globals.current_mode == 0:
					Globals.x_gain = max(0.1, Globals.x_gain - 0.1)
					print("X gain:", Globals.x_gain)
					Globals.save_settings()
			
			KEY_E:
				if Globals.current_mode == 0:
					Globals.y_gain += 0.1
					print("Y gain:", Globals.y_gain)
					Globals.save_settings()
			
			KEY_R:
				if Globals.current_mode == 0:
					Globals.y_gain = max(0.1, Globals.y_gain - 0.1)
					print("Y gain:", Globals.y_gain)
					Globals.save_settings()
			
			KEY_I:
				if Globals.current_mode == 0:
					Globals.invert_x = !Globals.invert_x
					print("Invert X:", Globals.invert_x)
					Globals.save_settings()
			
			KEY_O:
				if Globals.current_mode == 0:
					Globals.invert_y = !Globals.invert_y
					print("Invert Y:", Globals.invert_y)
					Globals.save_settings()
			
			KEY_T:
				if Globals.current_mode == 0:
					Globals.click_backward_threshold += 0.1
					print("Seuil recul:", Globals.click_backward_threshold)
					Globals.save_settings()
			
			KEY_Y:
				if Globals.current_mode == 0:
					Globals.click_backward_threshold = max(0.1, Globals.click_backward_threshold - 0.1)
					print("Seuil recul:", Globals.click_backward_threshold)
					Globals.save_settings()
			
			KEY_U:
				match Globals.current_mode:
					0:
						Globals.head_tracking_cooldown = min(2.0, Globals.head_tracking_cooldown + 0.1)
						print("Cooldown Head Tracking:", Globals.head_tracking_cooldown)
						Globals.save_settings()
					1:
						Globals.controller_cooldown = min(2.0, Globals.controller_cooldown + 0.1)
						print("Cooldown Manette:", Globals.controller_cooldown)
						Globals.save_settings()
					2:
						Globals.mouse_cooldown = min(2.0, Globals.mouse_cooldown + 0.1)
						print("Cooldown Souris:", Globals.mouse_cooldown)
						Globals.save_settings()
			
			KEY_J:
				match Globals.current_mode:
					0:
						Globals.head_tracking_cooldown = max(0.1, Globals.head_tracking_cooldown - 0.1)
						print("Cooldown Head Tracking:", Globals.head_tracking_cooldown)
						Globals.save_settings()
					1:
						Globals.controller_cooldown = max(0.1, Globals.controller_cooldown - 0.1)
						print("Cooldown Manette:", Globals.controller_cooldown)
						Globals.save_settings()
					2:
						Globals.mouse_cooldown = max(0.1, Globals.mouse_cooldown - 0.1)
						print("Cooldown Souris:", Globals.mouse_cooldown)
						Globals.save_settings()
			
			KEY_H:
				Globals.head_tracking_cooldown = min(2.0, Globals.head_tracking_cooldown + 0.1)
				print("Cooldown Head Tracking:", Globals.head_tracking_cooldown)
				Globals.save_settings()
			
			KEY_N:
				Globals.head_tracking_cooldown = max(0.1, Globals.head_tracking_cooldown - 0.1)
				print("Cooldown Head Tracking:", Globals.head_tracking_cooldown)
				Globals.save_settings()
			
			KEY_G:
				Globals.controller_cooldown = min(2.0, Globals.controller_cooldown + 0.1)
				print("Cooldown Manette:", Globals.controller_cooldown)
				Globals.save_settings()
			
			KEY_B:
				Globals.controller_cooldown = max(0.1, Globals.controller_cooldown - 0.1)
				print("Cooldown Manette:", Globals.controller_cooldown)
				Globals.save_settings()
			
			KEY_V:
				Globals.mouse_cooldown = min(2.0, Globals.mouse_cooldown + 0.1)
				print("Cooldown Souris:", Globals.mouse_cooldown)
				Globals.save_settings()
			
			KEY_F:
				Globals.mouse_cooldown = max(0.1, Globals.mouse_cooldown - 0.1)
				print("Cooldown Souris:", Globals.mouse_cooldown)
				Globals.save_settings()
			
			KEY_1:
				if Globals.current_mode == 0:
					Globals.backward_axis_index = 0
					print("Axe recul changé à: 0")
					Globals.save_settings()
			
			KEY_2:
				if Globals.current_mode == 0:
					Globals.backward_axis_index = 1
					print("Axe recul changé à: 1")
					Globals.save_settings()
			
			KEY_3:
				if Globals.current_mode == 0:
					Globals.backward_axis_index = 2
					print("Axe recul changé à: 2")
					Globals.save_settings()
			
			KEY_4:
				if Globals.current_mode == 0:
					Globals.backward_axis_index = 3
					print("Axe recul changé à: 3")
					Globals.save_settings()
			
			KEY_5:
				if Globals.current_mode == 0:
					Globals.backward_axis_index = 4
					print("Axe recul changé à: 4")
					Globals.save_settings()
			
			KEY_6:
				if Globals.current_mode == 0:
					Globals.backward_axis_index = 5
					print("Axe recul changé à: 5")
					Globals.save_settings()
			
			KEY_K:
				if Globals.current_mode == 0:
					Globals.backward_invert = !Globals.backward_invert
					print("Invert recul:", Globals.backward_invert)
					Globals.save_settings()
			
			KEY_L:
				if Globals.current_mode == 2:
					Globals.mouse_sensitivity += 0.1
					Globals.mouse_sensitivity = min(Globals.mouse_sensitivity, 3.0)
					print("Sensibilité souris:", Globals.mouse_sensitivity)
					Globals.save_settings()
			
			KEY_P:
				if Globals.current_mode == 2:
					Globals.mouse_sensitivity -= 0.1
					Globals.mouse_sensitivity = max(Globals.mouse_sensitivity, 0.1)
					print("Sensibilité souris:", Globals.mouse_sensitivity)
					Globals.save_settings()
			
			KEY_C:
				print("=== CLIC MANUEL ===")
				left_click.emit() #--------------------------------------------------------------------------------------------
				trigger_click(Globals.current_mode)
			
			KEY_SPACE:
				Globals.screen_pos = Globals.screen_center
				Globals.target_screen_pos = Globals.screen_center
				tracker_rect.position = Globals.screen_center
				print("Curseur recentré")
			
			KEY_F5:
				Globals.save_settings()
				print("Paramètres sauvegardés")
			
			KEY_F6:
				Globals.load_settings()
				print("Paramètres chargés")
			
			KEY_F7:
				Globals.reset_to_default()
				print("Paramètres réinitialisés")
			
			KEY_ESCAPE:
				get_tree().quit()

func remap(value, from_min, from_max, to_min, to_max):
	return (value - from_min) * (to_max - to_min) / (from_max - from_min) + to_min

func update_display():
	if Globals.show_debug_interface:
		var current_time = Time.get_ticks_msec() / 1000.0
		
		var time_since_head_click = current_time - Globals.last_head_tracking_click
		var time_since_controller_click = current_time - Globals.last_controller_click
		var time_since_mouse_click = current_time - Globals.last_mouse_click
		
		var head_cooldown_remaining = max(0, Globals.head_tracking_cooldown - time_since_head_click)
		var controller_cooldown_remaining = max(0, Globals.controller_cooldown - time_since_controller_click)
		var mouse_cooldown_remaining = max(0, Globals.mouse_cooldown - time_since_mouse_click)
		
		var backward_progress = Globals.backward_hold_time / Globals.BACKWARD_HOLD_THRESHOLD
		
		var text = "PARAMETTRE \n\n"
		
		text += "=== MODE ACTUEL ===\n"
		match Globals.current_mode:
			0:
				text += "HEAD TRACKING (OpenTrack) - RECTANGLE VERT\n"
			1:
				text += "MANETTE (Xbox) - RECTANGLE CYAN\n"
				text += "Vitesse: " + str(int(Globals.controller_speed)) + "\n"
			2:
				text += "SOURIS - RECTANGLE JAUNE\n"
				text += "Vitesse: " + str(snapped(Globals.mouse_speed, 0.1)) + "\n"
				text += "Sensibilité: " + str(snapped(Globals.mouse_sensitivity, 0.1)) + "\n"
		
		text += "\n"
		
		if Globals.current_mode == 0:
			text += "=== TOUS LES AXES ===\n"
			for i in range(6):
				var marker = " ← RECUL" if i == Globals.backward_axis_index else ""
				text += "Axe " + str(i) + ": " + str(snapped(Globals.all_axes[i], 0.1)) + marker + "\n"
			
			text += "\n=== RECUL ACTUEL (Axe " + str(Globals.backward_axis_index) + ") ===\n"
			text += "Valeur: " + str(snapped(Globals.filtered_backward, 0.1)) + "\n"
			text += "Seuil: " + str(snapped(Globals.click_backward_threshold, 0.1)) + "\n"
			text += "Maintenu: " + str(snapped(Globals.backward_hold_time, 0.1)) + "s / " + str(Globals.BACKWARD_HOLD_THRESHOLD) + "s\n"
			text += "Progression: " + str(int(backward_progress * 100)) + "%\n"
			text += "Max détecté: " + str(snapped(Globals.max_backward_detected, 0.1)) + "\n"
			text += "Inversion: " + ("ON" if Globals.backward_invert else "OFF") + "\n\n"
			
			text += "=== CURSEUR ===\n"
			text += "Position: " + str(int(tracker_rect.position.x)) + ", " + str(int(tracker_rect.position.y)) + "\n"
			text += "X (axe1): " + str(snapped(Globals.raw_x, 0.001)) + " rad\n"
			text += "Y (axe3): " + str(snapped(Globals.raw_y, 0.001)) + " rad\n"
		else:
			text += "=== CURSEUR ===\n"
			text += "Position: " + str(int(tracker_rect.position.x)) + ", " + str(int(tracker_rect.position.y)) + "\n"
		
		text += "\n=== CLICS PAR MODE ===\n"
		text += "Head Tracking: "
		if Globals.last_head_tracking_click == 0:
			text += "Jamais"
		else:
			text += str(snapped(time_since_head_click, 0.1)) + "s ago"
		text += " (Cooldown: " + str(snapped(Globals.head_tracking_cooldown, 0.1)) + "s)\n"
		
		text += "Manette: "
		if Globals.last_controller_click == 0:
			text += "Jamais"
		else:
			text += str(snapped(time_since_controller_click, 0.1)) + "s ago"
		text += " (Cooldown: " + str(snapped(Globals.controller_cooldown, 0.1)) + "s)\n"
		
		text += "Souris: "
		if Globals.last_mouse_click == 0:
			text += "Jamais"
		else:
			text += str(snapped(time_since_mouse_click, 0.1)) + "s ago"
		text += " (Cooldown: " + str(snapped(Globals.mouse_cooldown, 0.1)) + "s)\n"
		
		text += "\n=== COOLDOWN ACTUEL ===\n"
		match Globals.current_mode:
			0:
				text += "Temps restant: " + str(snapped(head_cooldown_remaining, 0.1)) + "s\n"
			1:
				text += "Temps restant: " + str(snapped(controller_cooldown_remaining, 0.1)) + "s\n"
			2:
				text += "Temps restant: " + str(snapped(mouse_cooldown_remaining, 0.1)) + "s\n"
		
		text += "\n=== RÉGLAGES ===\n"
		text += "X offset: " + str(snapped(Globals.x_offset, 0.1)) + "\n"
		text += "Y offset: " + str(snapped(Globals.y_offset, 0.1)) + "\n"
		text += "X gain: " + str(snapped(Globals.x_gain, 0.1)) + "\n"
		text += "Y gain: " + str(snapped(Globals.y_gain, 0.1)) + "\n"
		text += "Invert X: " + ("ON" if Globals.invert_x else "OFF") + "\n"
		text += "Invert Y: " + ("ON" if Globals.invert_y else "OFF") + "\n"
		
		if Globals.current_mode == 0:
			text += "Axe recul: " + str(Globals.backward_axis_index) + "\n"
			text += "Seuil recul: " + str(snapped(Globals.click_backward_threshold, 0.1)) + "\n"
			text += "Invert recul: " + ("ON" if Globals.backward_invert else "OFF") + "\n"
		
		text += "Lissage: " + str(snapped(Globals.smoothing, 0.1)) + "\n\n"
		
		text += "=== CONTROLES ===\n"
		text += "F1: Afficher/Masquer cette interface\n"
		text += "M: Basculer entre les modes\n"
		text += "C: Test clic manuel (mode actuel)\n"
		text += "ESPACE: Centre curseur\n"
		text += "F5: Sauvegarder paramètres\n"
		text += "F6: Charger paramètres\n"
		text += "F7: Réinitialiser paramètres\n"
		text += "ECHAP: Quitter\n\n"
		
		text += "=== RÉGLAGES COOLDOWNS ===\n"
		text += "U/J: Cooldown du mode actuel +/- 0.1s\n"
		text += "H/N: Cooldown Head Tracking +/- 0.1s\n"
		text += "G/B: Cooldown Manette +/- 0.1s\n"
		text += "V/F: Cooldown Souris +/- 0.1s\n\n"
		
		if Globals.current_mode == 0:
			text += "Flèches: Offset curseur X/Y\n"
			text += "A/Z: Gain curseur X\n"
			text += "E/R: Gain curseur Y\n"
			text += "I/O: Inversion axes X/Y\n"
			text += "T/Y: Seuil recul +/- 0.1\n"
			text += "1-6: Changer axe recul\n"
			text += "K: Inverser axe recul\n"
		elif Globals.current_mode == 1:
			text += "Manette:\n"
			text += "  Stick Gauche: Déplacement\n"
			text += "  A: Clic\n"
			text += "  B: Recentrer\n"
			text += "  X: Vitesse +50\n"
			text += "  Y: Vitesse -50\n"
			text += "  RB: X Gain +0.1\n"
			text += "  LB: X Gain -0.1\n"
		elif Globals.current_mode == 2:
			text += "Souris:\n"
			text += "  Déplacement: Bouger curseur\n"
			text += "  Clic Gauche: Clic\n"
			text += "  Clic Droit: Recentrer\n"
			text += "  Molette: Vitesse +/- 0.1\n"
			text += "  L/P: Sensibilité +/- 0.1\n"
		
		debug_label.text = text


func send_real_left_click():
	var click_press := InputEventMouseButton.new()
	click_press.button_index = MOUSE_BUTTON_LEFT
	click_press.pressed = true
	click_press.position = tracker_rect.position
	click_press.global_position = tracker_rect.position

	var click_release := InputEventMouseButton.new()
	click_release.button_index = MOUSE_BUTTON_LEFT
	click_release.pressed = false
	click_release.position = tracker_rect.position
	click_release.global_position = tracker_rect.position

	Input.parse_input_event(click_press)
	Input.parse_input_event(click_release)



func _exit_tree():
	if udp.is_bound():
		udp.close()
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
