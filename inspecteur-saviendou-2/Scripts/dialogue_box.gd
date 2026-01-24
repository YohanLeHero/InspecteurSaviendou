extends Panel

var speed : float = 100
var typingTime : float

func close():
	visible = false

func open():
	visible = true

func writeDialogue(description : Array[String]):
	get_tree().paused = true
	$Label.visible_characters = 0
	typingTime = 0
	open()
	for i in range(description.size()):
		self.get_node("Label").text = description[i]
		while $Label.visible_characters < $Label.get_total_character_count():
			typingTime += get_process_delta_time()
			$Label.visible_characters = typingTime * speed as int
			await get_tree().process_frame
		await $Button.pressed 
	close()
	get_tree().paused = false
