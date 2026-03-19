extends Node

const RANGE_MAX: float = 1024

var player: Node3D
var map_bound_min: Node3D
var map_bound_max: Node3D

func set_player(object: Node3D) -> void:
	player = object
func set_map_bound_min(object: Node3D) -> void:
	map_bound_min = object
func set_map_bound_max(object: Node3D) -> void:
	map_bound_max = object


func get_player_info() -> Dictionary:
	return {
		"name" : player.name,
		"location": get_player_location(),
		"custom": {}
	}

func get_player_location() -> Dictionary:
	var min_x := map_bound_min.transform.origin.x
	var max_x := map_bound_max.transform.origin.x
	var min_z := map_bound_min.transform.origin.z
	var max_z := map_bound_max.transform.origin.z
	var player_x := player.transform.origin.x
	var player_z := player.transform.origin.z
	
	var normalized_x: float = snapped(((player_x - min_x) / (max_x - min_x)) * RANGE_MAX, 0.001)
	var normalized_z: float = snapped(((player_z - min_z) / (max_z - min_z)) * RANGE_MAX, 0.001)
	
	var out_of_bounds := false
	if player_x > max_x || player_x < min_x:
		out_of_bounds = true
	if player_z > max_z || player_z < min_z:
		out_of_bounds = true
	
	return { "x": normalized_x, "y": normalized_z, "out_of_bounds": out_of_bounds, "range_max" : RANGE_MAX }

## reset GameQuery vars to be set by new scene.
## RUN BEFORE CHANGING SCENE!
func prep_scene_change() -> void:
	player = null
	map_bound_min = null
	map_bound_max = null
