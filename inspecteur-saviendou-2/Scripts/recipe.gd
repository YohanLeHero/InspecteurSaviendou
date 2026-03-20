extends Node2D

@export var Item1 : Node2D
@export var Item2 : Node2D
@export var Item3 : Node2D
@export var Result : Node2D

func getItem1():
	if Item1 != null:
		return Item1.name
	
func getItem2():
	if Item2 != null:
		return Item2.name

func getItem3():
	if Item3 != null:
		return Item3.name

func getResult():
	return Result
