@tool

extends SubViewport

class_name MapGeneratorViewport

## Sets global_position of the Camera3D in this Viewport.
func set_position(_position: Vector3) -> void:
	$Camera3D.set_global_position(_position)
