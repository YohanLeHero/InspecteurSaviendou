extends Node2D


signal nameClicked(name : String)

func send_name(name : String):
	nameClicked.emit(name)
