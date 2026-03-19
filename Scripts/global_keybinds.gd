extends Node

func _process(delta: float) -> void:
	if Input.is_action_pressed("quit"):
		exit_game()
	
func exit_game() -> void:
	get_tree().quit(0)
