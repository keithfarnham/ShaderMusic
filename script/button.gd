extends Button

#this is just to add a buffer before audio starts when recording vids

var timeout = 0.0
const AUTO_START = 5.0;

func _process(delta):
	timeout += delta
	if timeout > AUTO_START:
		get_tree().change_scene_to_file("res://scenes/dunban.tscn")

func _on_pressed():
	print("pressed")
	get_tree().change_scene_to_file("res://scenes/dunban.tscn")
