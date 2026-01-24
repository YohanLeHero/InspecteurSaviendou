extends Node2D

@onready var tracker_rect = $TrackerRect
@onready var debug_label = $ScrollContainer/Label
@onready var scroll_container = $ScrollContainer  # Référence au ScrollContainer

var udp := PacketPeerUDP.new()
const PORT = 4242

# Variables
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
var smoothing = 0.7
var prediction = 0.2
var deadzone = 0.02

# Détection de clic par RECUL (axe 5)
var click_backward_threshold = 0.5
var backward_hold_time = 0.0
const BACKWARD_HOLD_THRESHOLD = 0.3
var max_backward_detected = 0.0
var backward_axis_index = 5
var backward_invert = false

# Cooldowns séparés pour chaque mode
var head_tracking_cooldown = 0.5
var controller_cooldown = 0.3
var mouse_cooldown = 0.2

# Derniers clics par mode
var last_head_tracking_click = 0.0
var last_controller_click = 0.0
var last_mouse_click = 0.0

# Modes de contrôle (0 = head tracking, 1 = manette, 2 = souris)
var current_mode = 0
var controller_speed = 500.0
var controller_deadzone = 0.2
var mouse_speed = 1.0

# Boutons manette
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

# Debug tous les axes
var all_axes = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

# Variables souris
var mouse_motion = Vector2.ZERO
var mouse_sensitivity = 1.0
var mouse_accumulated = Vector2.ZERO
var mouse_position = Vector2.ZERO
var mouse_cursor_visible = true

# Variable pour afficher/masquer l'interface
var show_debug_interface = true

func _ready():
	print("EYE TRACKING - MULTIMODE AVEC COOLDOWNS SÉPARÉS")
	
	screen_size = get_viewport().get_visible_rect().size
	screen_center = screen_size / 2
	screen_pos = screen_center
	target_screen_pos = screen_center
	mouse_position = screen_center
	
	tracker_rect.position = screen_center
	tracker_rect.modulate = Color.GREEN
	tracker_rect.scale = Vector2(0.3, 0.3)
	
	# Cacher le curseur de la souris
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	
	if udp.bind(PORT) == OK:
		print("Connecté au port", PORT)
		debug_label.text = "Attente de données..."
	else:
		debug_label.text = "Erreur de connexion"

func _process(delta):
	match current_mode:
		0:
			process_head_tracking(delta)
		1:
			process_controller(delta)
		2:
			process_mouse(delta)
	
	update_display()

func process_head_tracking(delta):
	var packets_processed = 0
	
	while udp.get_available_packet_count() > 0:
		var packet = udp.get_packet()
		
		if packet.size() >= 24:
			raw_x = packet.decode_float(4)
			raw_y = packet.decode_float(12)
			
			for i in range(0, min(6, packet.size() / 4)):
				all_axes[i] = packet.decode_float(i * 4)
			
			raw_roll = all_axes[backward_axis_index]
			
			packets_processed += 1
			
			velocity_x = raw_x - last_raw_x
			velocity_y = raw_y - last_raw_y
			last_raw_x = raw_x
			last_raw_y = raw_y
			
			buffer_x.push_back(raw_x)
			buffer_y.push_back(raw_y)
			
			if buffer_x.size() > BUFFER_SIZE:
				buffer_x.pop_front()
			if buffer_y.size() > BUFFER_SIZE:
				buffer_y.pop_front()
	
	if packets_processed > 0:
		var weighted_x = 0.0
		var weighted_y = 0.0
		var total_weight = 0.0
		
		for i in range(buffer_x.size()):
			var weight = (i + 1) / float(buffer_x.size())
			weighted_x += buffer_x[i] * weight
			weighted_y += buffer_y[i] * weight
			total_weight += weight
		
		if total_weight > 0:
			weighted_x /= total_weight
			weighted_y /= total_weight
		
		last_filtered_x = filtered_x
		last_filtered_y = filtered_y
		
		filtered_x = filtered_x * (1.0 - FILTER_STRENGTH) + weighted_x * FILTER_STRENGTH
		filtered_y = filtered_y * (1.0 - FILTER_STRENGTH) + weighted_y * FILTER_STRENGTH
		filtered_backward = filtered_backward * (1.0 - FILTER_STRENGTH) + raw_roll * FILTER_STRENGTH
		
		var adjusted_x = (filtered_x + x_offset) * x_gain
		var adjusted_y = (filtered_y + y_offset) * y_gain
		
		if invert_x:
			adjusted_x = -adjusted_x
		if invert_y:
			adjusted_y = -adjusted_y
		
		if abs(adjusted_x) < deadzone:
			adjusted_x = 0.0
		if abs(adjusted_y) < deadzone:
			adjusted_y = 0.0
		
		adjusted_x = clamp(adjusted_x, -1.0, 1.0)
		adjusted_y = clamp(adjusted_y, -1.0, 1.0)
		
		detect_backward_for_click(delta)
		
		target_screen_pos = Vector2(
			remap(adjusted_x, -1.0, 1.0, margin, screen_size.x - margin),
			remap(adjusted_y, -1.0, 1.0, margin, screen_size.y - margin)
		)
	
	if packets_processed > 0:
		var predicted_x = velocity_x * prediction * 100
		var predicted_y = velocity_y * prediction * 100
		
		target_screen_pos.x += predicted_x
		target_screen_pos.y += predicted_y
	
	var distance = screen_pos.distance_to(target_screen_pos)
	var adaptive_smoothing = smoothing
	
	if distance < 10:
		adaptive_smoothing = smoothing * 0.8
	elif distance > 100:
		adaptive_smoothing = smoothing * 1.2
	
	var t = adaptive_smoothing * (1.0 - exp(-delta * 10.0))
	screen_pos = screen_pos.lerp(target_screen_pos, t)
	
	tracker_rect.position = screen_pos

func process_controller(delta):
	var left_stick_x = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var left_stick_y = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	
	if abs(left_stick_x) < controller_deadzone:
		left_stick_x = 0.0
	if abs(left_stick_y) < controller_deadzone:
		left_stick_y = 0.0
	
	var move_x = left_stick_x * controller_speed * delta
	var move_y = left_stick_y * controller_speed * delta
	
	target_screen_pos.x += move_x
	target_screen_pos.y += move_y
	
	target_screen_pos.x = clamp(target_screen_pos.x, margin, screen_size.x - margin)
	target_screen_pos.y = clamp(target_screen_pos.y, margin, screen_size.y - margin)
	
	var t = smoothing * (1.0 - exp(-delta * 10.0))
	screen_pos = screen_pos.lerp(target_screen_pos, t)
	
	tracker_rect.position = screen_pos
	
	detect_controller_buttons(delta)

func process_mouse(delta):
	var move_x = mouse_motion.x * mouse_speed * mouse_sensitivity
	var move_y = mouse_motion.y * mouse_speed * mouse_sensitivity
	
	mouse_accumulated.x += move_x
	mouse_accumulated.y += move_y
	
	if abs(mouse_accumulated.x) >= 1.0:
		target_screen_pos.x += int(mouse_accumulated.x)
		mouse_accumulated.x -= int(mouse_accumulated.x)
	
	if abs(mouse_accumulated.y) >= 1.0:
		target_screen_pos.y += int(mouse_accumulated.y)
		mouse_accumulated.y -= int(mouse_accumulated.y)
	
	target_screen_pos.x = clamp(target_screen_pos.x, margin, screen_size.x - margin)
	target_screen_pos.y = clamp(target_screen_pos.y, margin, screen_size.y - margin)
	
	var t = smoothing * (1.0 - exp(-delta * 10.0))
	screen_pos = screen_pos.lerp(target_screen_pos, t)
	
	tracker_rect.position = screen_pos
	
	mouse_motion = Vector2.ZERO
	
	detect_mouse_clicks(delta)

func detect_backward_for_click(delta):
	var current_time = Time.get_ticks_msec() / 1000.0
	var time_since_last_click = current_time - last_head_tracking_click
	
	var backward_value = filtered_backward
	if backward_invert:
		backward_value = -backward_value
	
	if abs(backward_value) > abs(max_backward_detected):
		max_backward_detected = backward_value
	
	if backward_value > click_backward_threshold:
		backward_hold_time += delta
		
		if backward_hold_time >= BACKWARD_HOLD_THRESHOLD and time_since_last_click > head_tracking_cooldown:
			trigger_click(0)
			backward_hold_time = 0.0
			last_head_tracking_click = current_time
	else:
		backward_hold_time = 0.0

func detect_controller_buttons(delta):
	var current_time = Time.get_ticks_msec() / 1000.0
	var time_since_last_click = current_time - last_controller_click
	
	if Input.is_joy_button_pressed(0, JOY_BUTTON_A):
		if time_since_last_click > controller_cooldown:
			trigger_click(1)
			last_controller_click = current_time
	
	if Input.is_joy_button_pressed(0, JOY_BUTTON_B):
		screen_pos = screen_center
		target_screen_pos = screen_center
		tracker_rect.position = screen_center
	
	if Input.is_joy_button_pressed(0, JOY_BUTTON_X):
		controller_speed += 50.0
		controller_speed = min(controller_speed, 2000.0)
	
	if Input.is_joy_button_pressed(0, JOY_BUTTON_Y):
		controller_speed -= 50.0
		controller_speed = max(controller_speed, 50.0)
	
	if Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER):
		x_gain += 0.1
		print("X gain:", x_gain)
	
	if Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_SHOULDER):
		x_gain = max(0.1, x_gain - 0.1)
		print("X gain:", x_gain)

func detect_mouse_clicks(delta):
	var current_time = Time.get_ticks_msec() / 1000.0
	var time_since_last_click = current_time - last_mouse_click
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if time_since_last_click > mouse_cooldown:
			trigger_click(2)
			last_mouse_click = current_time
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		screen_pos = screen_center
		target_screen_pos = screen_center
		tracker_rect.position = screen_center
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_WHEEL_UP):
		mouse_speed += 0.1
		mouse_speed = min(mouse_speed, 5.0)
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_WHEEL_DOWN):
		mouse_speed -= 0.1
		mouse_speed = max(mouse_speed, 0.1)

func trigger_click(mode_index):
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
		match current_mode:
			0: tracker_rect.modulate = Color.GREEN
			1: tracker_rect.modulate = Color.CYAN
			2: tracker_rect.modulate = Color.YELLOW
	)

func _input(event):
	if current_mode == 2 and event is InputEventMouseMotion:
		mouse_motion = event.relative
	
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F1:
				# Basculer l'affichage de l'interface de débogage
				show_debug_interface = !show_debug_interface
				scroll_container.visible = show_debug_interface
				print("Interface debug: ", "ON" if show_debug_interface else "OFF")
			
			KEY_M:
				current_mode = (current_mode + 1) % 3
				var mode_names = ["HEAD TRACKING", "MANETTE", "SOURIS"]
				print("Mode changé: ", mode_names[current_mode])
				
				match current_mode:
					0: tracker_rect.modulate = Color.GREEN
					1: tracker_rect.modulate = Color.CYAN
					2: tracker_rect.modulate = Color.YELLOW
				
				if current_mode == 2:
					Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				else:
					#Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
					Input.warp_mouse(tracker_rect.position)
			
			KEY_LEFT:
				if current_mode == 0:
					x_offset -= 0.1
					print("X offset:", x_offset)
			
			KEY_RIGHT:
				if current_mode == 0:
					x_offset += 0.1
					print("X offset:", x_offset)
			
			KEY_UP:
				if current_mode == 0:
					y_offset -= 0.1
					print("Y offset:", y_offset)
			
			KEY_DOWN:
				if current_mode == 0:
					y_offset += 0.1
					print("Y offset:", y_offset)
			
			KEY_A:
				if current_mode == 0:
					x_gain += 0.1
					print("X gain:", x_gain)
			
			KEY_Z:
				if current_mode == 0:
					x_gain = max(0.1, x_gain - 0.1)
					print("X gain:", x_gain)
			
			KEY_E:
				if current_mode == 0:
					y_gain += 0.1
					print("Y gain:", y_gain)
			
			KEY_R:
				if current_mode == 0:
					y_gain = max(0.1, y_gain - 0.1)
					print("Y gain:", y_gain)
			
			KEY_I:
				if current_mode == 0:
					invert_x = !invert_x
					print("Invert X:", invert_x)
			
			KEY_O:
				if current_mode == 0:
					invert_y = !invert_y
					print("Invert Y:", invert_y)
			
			KEY_T:
				if current_mode == 0:
					click_backward_threshold += 0.1
					print("Seuil recul:", click_backward_threshold)
			
			KEY_Y:
				if current_mode == 0:
					click_backward_threshold = max(0.1, click_backward_threshold - 0.1)
					print("Seuil recul:", click_backward_threshold)
			
			# Cooldowns - touches séparées pour chaque mode
			KEY_U:
				# Augmenter cooldown du mode actuel
				match current_mode:
					0:
						head_tracking_cooldown = min(2.0, head_tracking_cooldown + 0.1)
						print("Cooldown Head Tracking:", head_tracking_cooldown)
					1:
						controller_cooldown = min(2.0, controller_cooldown + 0.1)
						print("Cooldown Manette:", controller_cooldown)
					2:
						mouse_cooldown = min(2.0, mouse_cooldown + 0.1)
						print("Cooldown Souris:", mouse_cooldown)
			
			KEY_J:
				# Diminuer cooldown du mode actuel
				match current_mode:
					0:
						head_tracking_cooldown = max(0.1, head_tracking_cooldown - 0.1)
						print("Cooldown Head Tracking:", head_tracking_cooldown)
					1:
						controller_cooldown = max(0.1, controller_cooldown - 0.1)
						print("Cooldown Manette:", controller_cooldown)
					2:
						mouse_cooldown = max(0.1, mouse_cooldown - 0.1)
						print("Cooldown Souris:", mouse_cooldown)
			
			# Touches spéciales pour ajuster les cooldowns des autres modes
			KEY_H:
				# Augmenter cooldown Head Tracking (même si pas dans ce mode)
				head_tracking_cooldown = min(2.0, head_tracking_cooldown + 0.1)
				print("Cooldown Head Tracking:", head_tracking_cooldown)
			
			KEY_N:
				# Diminuer cooldown Head Tracking
				head_tracking_cooldown = max(0.1, head_tracking_cooldown - 0.1)
				print("Cooldown Head Tracking:", head_tracking_cooldown)
			
			KEY_G:
				# Augmenter cooldown Manette
				controller_cooldown = min(2.0, controller_cooldown + 0.1)
				print("Cooldown Manette:", controller_cooldown)
			
			KEY_B:
				# Diminuer cooldown Manette
				controller_cooldown = max(0.1, controller_cooldown - 0.1)
				print("Cooldown Manette:", controller_cooldown)
			
			KEY_V:
				# Augmenter cooldown Souris
				mouse_cooldown = min(2.0, mouse_cooldown + 0.1)
				print("Cooldown Souris:", mouse_cooldown)
			
			KEY_F:
				# Diminuer cooldown Souris
				mouse_cooldown = max(0.1, mouse_cooldown - 0.1)
				print("Cooldown Souris:", mouse_cooldown)
			
			KEY_1:
				if current_mode == 0:
					backward_axis_index = 0
					print("Axe recul changé à: 0")
			
			KEY_2:
				if current_mode == 0:
					backward_axis_index = 1
					print("Axe recul changé à: 1")
			
			KEY_3:
				if current_mode == 0:
					backward_axis_index = 2
					print("Axe recul changé à: 2")
			
			KEY_4:
				if current_mode == 0:
					backward_axis_index = 3
					print("Axe recul changé à: 3")
			
			KEY_5:
				if current_mode == 0:
					backward_axis_index = 4
					print("Axe recul changé à: 4")
			
			KEY_6:
				if current_mode == 0:
					backward_axis_index = 5
					print("Axe recul changé à: 5")
			
			KEY_K:
				if current_mode == 0:
					backward_invert = !backward_invert
					print("Invert recul:", backward_invert)
			
			KEY_L:  # Sensibilité souris
				if current_mode == 2:
					mouse_sensitivity += 0.1
					mouse_sensitivity = min(mouse_sensitivity, 3.0)
					print("Sensibilité souris:", mouse_sensitivity)
			
			KEY_P:  # Sensibilité souris
				if current_mode == 2:
					mouse_sensitivity -= 0.1
					mouse_sensitivity = max(mouse_sensitivity, 0.1)
					print("Sensibilité souris:", mouse_sensitivity)
			
			KEY_C:
				print("=== CLIC MANUEL ===")
				trigger_click(current_mode)
			
			KEY_SPACE:
				screen_pos = screen_center
				target_screen_pos = screen_center
				tracker_rect.position = screen_center
				print("Curseur recentré")
			
			KEY_ESCAPE:
				get_tree().quit()

func remap(value, from_min, from_max, to_min, to_max):
	return (value - from_min) * (to_max - to_min) / (from_max - from_min) + to_min

func update_display():
	# Mettre à jour l'affichage seulement si l'interface est visible
	if show_debug_interface:
		var current_time = Time.get_ticks_msec() / 1000.0
		
		# Temps depuis dernier clic pour chaque mode
		var time_since_head_click = current_time - last_head_tracking_click
		var time_since_controller_click = current_time - last_controller_click
		var time_since_mouse_click = current_time - last_mouse_click
		
		# Cooldown restant pour chaque mode
		var head_cooldown_remaining = max(0, head_tracking_cooldown - time_since_head_click)
		var controller_cooldown_remaining = max(0, controller_cooldown - time_since_controller_click)
		var mouse_cooldown_remaining = max(0, mouse_cooldown - time_since_mouse_click)
		
		var backward_progress = backward_hold_time / BACKWARD_HOLD_THRESHOLD
		
		var text = "EYE TRACKING - MULTIMODE AVEC COOLDOWNS SÉPARÉS\n\n"
		
		text += "=== MODE ACTUEL ===\n"
		match current_mode:
			0:
				text += "HEAD TRACKING (OpenTrack) - RECTANGLE VERT\n"
			1:
				text += "MANETTE (Xbox) - RECTANGLE CYAN\n"
				text += "Vitesse: " + str(int(controller_speed)) + "\n"
			2:
				text += "SOURIS - RECTANGLE JAUNE\n"
				text += "Vitesse: " + str(snapped(mouse_speed, 0.1)) + "\n"
				text += "Sensibilité: " + str(snapped(mouse_sensitivity, 0.1)) + "\n"
		
		text += "\n"
		
		if current_mode == 0:
			text += "=== TOUS LES AXES ===\n"
			for i in range(6):
				var marker = " ← RECUL" if i == backward_axis_index else ""
				text += "Axe " + str(i) + ": " + str(snapped(all_axes[i], 0.1)) + marker + "\n"
			
			text += "\n=== RECUL ACTUEL (Axe " + str(backward_axis_index) + ") ===\n"
			text += "Valeur: " + str(snapped(filtered_backward, 0.1)) + "\n"
			text += "Seuil: " + str(snapped(click_backward_threshold, 0.1)) + "\n"
			text += "Maintenu: " + str(snapped(backward_hold_time, 0.1)) + "s / " + str(BACKWARD_HOLD_THRESHOLD) + "s\n"
			text += "Progression: " + str(int(backward_progress * 100)) + "%\n"
			text += "Max détecté: " + str(snapped(max_backward_detected, 0.1)) + "\n"
			text += "Inversion: " + ("ON" if backward_invert else "OFF") + "\n\n"
			
			text += "=== CURSEUR ===\n"
			text += "Position: " + str(int(tracker_rect.position.x)) + ", " + str(int(tracker_rect.position.y)) + "\n"
			text += "X (axe1): " + str(snapped(raw_x, 0.001)) + " rad\n"
			text += "Y (axe3): " + str(snapped(raw_y, 0.001)) + " rad\n"
		else:
			text += "=== CURSEUR ===\n"
			text += "Position: " + str(int(tracker_rect.position.x)) + ", " + str(int(tracker_rect.position.y)) + "\n"
		
		text += "\n=== CLICS PAR MODE ===\n"
		text += "Head Tracking: "
		if last_head_tracking_click == 0:
			text += "Jamais"
		else:
			text += str(snapped(time_since_head_click, 0.1)) + "s ago"
		text += " (Cooldown: " + str(snapped(head_tracking_cooldown, 0.1)) + "s)\n"
		
		text += "Manette: "
		if last_controller_click == 0:
			text += "Jamais"
		else:
			text += str(snapped(time_since_controller_click, 0.1)) + "s ago"
		text += " (Cooldown: " + str(snapped(controller_cooldown, 0.1)) + "s)\n"
		
		text += "Souris: "
		if last_mouse_click == 0:
			text += "Jamais"
		else:
			text += str(snapped(time_since_mouse_click, 0.1)) + "s ago"
		text += " (Cooldown: " + str(snapped(mouse_cooldown, 0.1)) + "s)\n"
		
		text += "\n=== COOLDOWN ACTUEL ===\n"
		match current_mode:
			0:
				text += "Temps restant: " + str(snapped(head_cooldown_remaining, 0.1)) + "s\n"
			1:
				text += "Temps restant: " + str(snapped(controller_cooldown_remaining, 0.1)) + "s\n"
			2:
				text += "Temps restant: " + str(snapped(mouse_cooldown_remaining, 0.1)) + "s\n"
		
		text += "\n=== RÉGLAGES ===\n"
		text += "X offset: " + str(snapped(x_offset, 0.1)) + "\n"
		text += "Y offset: " + str(snapped(y_offset, 0.1)) + "\n"
		text += "X gain: " + str(snapped(x_gain, 0.1)) + "\n"
		text += "Y gain: " + str(snapped(y_gain, 0.1)) + "\n"
		text += "Invert X: " + ("ON" if invert_x else "OFF") + "\n"
		text += "Invert Y: " + ("ON" if invert_y else "OFF") + "\n"
		
		if current_mode == 0:
			text += "Axe recul: " + str(backward_axis_index) + "\n"
			text += "Seuil recul: " + str(snapped(click_backward_threshold, 0.1)) + "\n"
			text += "Invert recul: " + ("ON" if backward_invert else "OFF") + "\n"
		
		text += "Lissage: " + str(snapped(smoothing, 0.1)) + "\n\n"
		
		text += "=== CONTROLES ===\n"
		text += "F1: Afficher/Masquer cette interface\n"
		text += "M: Basculer entre les modes\n"
		text += "C: Test clic manuel (mode actuel)\n"
		text += "ESPACE: Centre curseur\n"
		text += "ECHAP: Quitter\n\n"
		
		text += "=== RÉGLAGES COOLDOWNS ===\n"
		text += "U/J: Cooldown du mode actuel +/- 0.1s\n"
		text += "H/N: Cooldown Head Tracking +/- 0.1s\n"
		text += "G/B: Cooldown Manette +/- 0.1s\n"
		text += "V/F: Cooldown Souris +/- 0.1s\n\n"
		
		if current_mode == 0:
			text += "Flèches: Offset curseur X/Y\n"
			text += "A/Z: Gain curseur X\n"
			text += "E/R: Gain curseur Y\n"
			text += "I/O: Inversion axes X/Y\n"
			text += "T/Y: Seuil recul +/- 0.1\n"
			text += "1-6: Changer axe recul\n"
			text += "K: Inverser axe recul\n"
		elif current_mode == 1:
			text += "Manette:\n"
			text += "  Stick Gauche: Déplacement\n"
			text += "  A: Clic\n"
			text += "  B: Recentrer\n"
			text += "  X: Vitesse +50\n"
			text += "  Y: Vitesse -50\n"
			text += "  RB: X Gain +0.1\n"
			text += "  LB: X Gain -0.1\n"
		elif current_mode == 2:
			text += "Souris:\n"
			text += "  Déplacement: Bouger curseur\n"
			text += "  Clic Gauche: Clic\n"
			text += "  Clic Droit: Recentrer\n"
			text += "  Molette: Vitesse +/- 0.1\n"
			text += "  L/P: Sensibilité +/- 0.1\n"
		
		debug_label.text = text

func _exit_tree():
	if udp.is_bound():
		udp.close()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
