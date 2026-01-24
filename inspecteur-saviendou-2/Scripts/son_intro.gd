extends Area2D

@onready var audio_player := $AudioStreamPlayer2D
var already_played := false

func _ready():
	self.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D):
	if already_played:
		return
	print("BODY ENTERED:", body.name)
	audio_player.play()
	already_played = true
