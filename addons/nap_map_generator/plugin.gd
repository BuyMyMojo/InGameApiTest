@tool
extends EditorPlugin

func _enter_tree() -> void:
	add_custom_type(
		'NapMapGenerator',
		'Node3D',
		preload('res://addons/nap_map_generator/map_generator.gd'),
		preload('res://addons/nap_map_generator/nap_softworks_3d_icon.svg')
	)


func _exit_tree() -> void:
	remove_custom_type('NapMapGenerator')
