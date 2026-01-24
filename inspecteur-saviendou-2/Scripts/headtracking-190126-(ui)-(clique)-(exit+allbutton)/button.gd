extends Button

@onready var menu: Panel = $"../Panel"

var menu_open := false
var menu_width := 400
var anim_time := 0.3

func _ready():
	if menu:
		# Ancres fixes pour pouvoir déplacer le Panel
		menu.anchors_preset = Control.PRESET_TOP_LEFT
		# Déplacer le Panel hors écran à gauche
		menu.position = Vector2(-menu_width, 0)

func _pressed():
	if not menu:
		return

	var target_x = 0 if not menu_open else -menu_width
	var tween = create_tween()
	tween.tween_property(menu, "position:x", target_x, anim_time)

	menu_open = !menu_open
