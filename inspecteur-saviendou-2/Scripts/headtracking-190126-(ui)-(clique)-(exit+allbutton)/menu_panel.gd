extends Panel

# =====================
# NODES
# =====================
@onready var options_container: VBoxContainer = $VBoxContainer/OptionsContainer
@onready var bottom_buttons: HBoxContainer = $VBoxContainer/BottomButtons

@onready var btn_save: Button = $VBoxContainer/BottomButtons/Save
@onready var btn_load: Button = $VBoxContainer/BottomButtons/Load
@onready var btn_reset: Button = $VBoxContainer/BottomButtons/Reset

@onready var btn_mouse: Button = $VBoxContainer/HBoxContainer/Souris
@onready var btn_controller: Button = $VBoxContainer/HBoxContainer/Manette
@onready var btn_head: Button = $VBoxContainer/HBoxContainer/HeadTracking


# =====================
# READY
# =====================
func _ready():
	btn_mouse.pressed.connect(func(): _set_mode(2))
	btn_controller.pressed.connect(func(): _set_mode(1))
	btn_head.pressed.connect(func(): _set_mode(0))

	btn_save.pressed.connect(_on_save_pressed)
	btn_load.pressed.connect(_on_load_pressed)
	btn_reset.pressed.connect(_on_reset_pressed)

	_refresh_ui()


# =====================
# MODE
# =====================
func _set_mode(mode: int):
	Globals.current_mode = mode
	call_deferred("_refresh_ui")


# =====================
# REFRESH UI
# =====================
func _refresh_ui():
	for c in options_container.get_children():
		c.queue_free()

	match Globals.current_mode:
		2: _build_mouse_ui()
		1: _build_controller_ui()
		0: _build_head_ui()


# =====================
# UI SOURIS
# =====================
func _build_mouse_ui():
	options_container.add_child(_section_title(" Souris"))

	options_container.add_child(_slider_card(
		" Sensibilité",
		Globals.mouse_sensitivity,
		0.1, 5.0, 0.05,
		func(v): Globals.mouse_sensitivity = v
	))

	options_container.add_child(_slider_card(
		" Cooldown clic",
		Globals.mouse_cooldown,
		0.05, 1.0, 0.01,
		func(v): Globals.mouse_cooldown = v
	))


# =====================
# UI MANETTE
# =====================
func _build_controller_ui():
	options_container.add_child(_section_title(" Manette"))

	options_container.add_child(_slider_card(
		" Vitesse",
		Globals.controller_speed,
		100.0, 2000.0, 10.0,
		func(v): Globals.controller_speed = v
	))

	options_container.add_child(_slider_card(
		" Deadzone",
		Globals.controller_deadzone,
		0.0, 1.0, 0.01,
		func(v): Globals.controller_deadzone = v
	))

	options_container.add_child(_slider_card(
		" Cooldown clic",
		Globals.controller_cooldown,
		0.05, 1.0, 0.01,
		func(v): Globals.controller_cooldown = v
	))


# =====================
# UI HEAD TRACKING (SCROLL)
# =====================
func _build_head_ui():
	options_container.add_child(_section_title(" Head Tracking"))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 320)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override(" separation", 10)

	scroll.add_child(content)
	options_container.add_child(scroll)

	content.add_child(_checkbox(" Inverser X", Globals.invert_x, func(v): Globals.invert_x = v))
	content.add_child(_checkbox(" Inverser Y", Globals.invert_y, func(v): Globals.invert_y = v))

	content.add_child(_slider_card(" Offset X", Globals.x_offset, -500, 500, 5, func(v): Globals.x_offset = v))
	content.add_child(_slider_card(" Offset Y", Globals.y_offset, -500, 500, 5, func(v): Globals.y_offset = v))
	content.add_child(_slider_card(" Gain X", Globals.x_gain, 0.1, 5.0, 0.05, func(v): Globals.x_gain = v))
	content.add_child(_slider_card(" Gain Y", Globals.y_gain, 0.1, 5.0, 0.05, func(v): Globals.y_gain = v))
	content.add_child(_slider_card(" Lissage", Globals.smoothing, 0.1, 5.0, 0.05, func(v): Globals.smoothing = v))
	content.add_child(_slider_card(" Prédiction", Globals.prediction, 0.0, 1.0, 0.01, func(v): Globals.prediction = v))
	content.add_child(_slider_card(" Deadzone", Globals.deadzone, 0.0, 0.2, 0.005, func(v): Globals.deadzone = v))
	content.add_child(_slider_card(" Seuil recul", Globals.click_backward_threshold, 0.1, 2.0, 0.05, func(v): Globals.click_backward_threshold = v))
	content.add_child(_slider_card(" Cooldown clic", Globals.head_tracking_cooldown, 0.05, 1.0, 0.01, func(v): Globals.head_tracking_cooldown = v))


# =====================
# UI HELPERS
# =====================
func _section_title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	return l


func _slider_card(label_text, value, min, max, step, callback):
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var label := Label.new()
	label.text = label_text

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var minus := Button.new()
	minus.text = "-"
	minus.custom_minimum_size = Vector2(28, 28)

	var slider := HSlider.new()
	slider.min_value = min
	slider.max_value = max
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(callback)

	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(28, 28)

	minus.pressed.connect(func(): slider.value = max(slider.min_value, slider.value - step))
	plus.pressed.connect(func(): slider.value = min(slider.max_value, slider.value + step))

	row.add_child(minus)
	row.add_child(slider)
	row.add_child(plus)

	box.add_child(label)
	box.add_child(row)
	return box


func _checkbox(label_text, value, callback):
	var cb := CheckBox.new()
	cb.text = label_text
	cb.button_pressed = value
	cb.toggled.connect(callback)
	return cb


# =====================
# BOTTOM BUTTONS
# =====================
func _on_save_pressed():
	Globals.save_settings()
	print("PARAMÈTRES SAUVÉS")


func _on_load_pressed():
	Globals.load_settings()
	_refresh_ui()
	print("PARAMÈTRES CHARGÉS")


func _on_reset_pressed():
	Globals.reset_to_default()
	_refresh_ui()
	print("PARAMÈTRES RÉINITIALISÉS")
