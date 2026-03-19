extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GameQuery.set_player($"Basic FPS Player")
	GameQuery.set_map_bound_min($MapExtents/MapMin)
	GameQuery.set_map_bound_max($MapExtents/MapMax)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
