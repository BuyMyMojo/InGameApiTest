@tool

extends Node3D

## NAP Map Generator addon useful for fast and easy (mini)map generation.
## The addon scans your game's 3D world and generates a top-down image of it,
## so you can use it in your game's map view or minimap radar.
## [br][br]
## Do not switch to other tabs until the scan finishes.
class_name NapMapGenerator

@export_tool_button('Generate map', 'Image') var generate_map_button: Callable = generate_map

@export_group('Settings')
## A parent node that holds all your level meshes. Based on this, the addon will
## scan all the VisualInstance3D children and calculate your level's boundaries.
@export var level_parent: Node3D

## The directory your map's image will be stored in. The name format is 
## [i]map_{LEVEL_PARENT_NODE_NAME}.png[/i]
@export_dir var image_directory: String = 'res://'

## Scale of the image you want to generate.[br][br]
## For example, having a 128x128m big 3D world will generate 128x128px image
## for scale of 1.0. For scale 2.0, the same world will generate 256x256px image.
## [br][br]
## [b]Note:[/b] Power of 2 is recommended value (2, 4, 8, 16, 32, ...).
@export var map_scale: int = 1

## Number of rows scanned simulatenously.
## The bigger the value, the faster the scan will be.[br][br]
## [b]Note:[/b] Setting this value above 64 might result in unwanted behavior.
@export var simulatenous_rows: int = 1

## PackedScene entity used for spawning viewports.
var map_generator_viewport_scene: PackedScene = load('res://addons/nap_map_generator/map_generator_viewport.tscn')

## An array of available viewports the addon will use to scan the map.
var map_generator_viewports: Array[MapGeneratorViewport] = []

## Current camera height
var camera_height: float = 0.0

## The map's image.
var map_image: Image

## The Y-offset of all the cameras scanning your map. Purely cosmetic thing,
## as it has no effect on the image unless set to a value below or equal 0.0.
const CAMERA_Y_OFFSET: float = 5.0

## Generates a map image of your 3D world.
func generate_map() -> void:
	if (!level_parent || !image_directory):
		_print_message('Could not generate a map. Please check your settings.', 'red')
		
		return
	
	_print_welcome_message()
	
	_print_message('Generating a map, please wait...', 'green')
	
	var initial_update_continuously: bool = _get_update_continuously_setting()
	
	# Set update_continuously settings so users can switch to other software.
	_set_update_continuously_setting(true)
	
	# Wait for all the viewports.
	await _populate_viewports()
	
	var level_parent_aabb: AABB = _calculate_aabb()
	var level_parent_size: Vector3 = level_parent_aabb.size
	var level_parent_starting_point: Vector3 = level_parent_aabb.position
	var level_parent_position: Vector3 = level_parent.get_global_position()
	var image_size_x: int = floori(level_parent_size.x * map_scale)
	var image_size_y: int = floori(level_parent_size.z * map_scale)
	
	camera_height = level_parent_aabb.size.y + CAMERA_Y_OFFSET
	
	await get_tree().process_frame
	
	map_image = null
	map_image = Image.create_empty(image_size_x, image_size_y, false, Image.FORMAT_RGBA8)
	
	# Iterate viewports over X and Z axes
	for z in range(0, level_parent_size.z, simulatenous_rows):
		for x in level_parent_size.x:
			if (!is_inside_tree()):
				_print_message('Map generation stopped. Please try again.', 'red')
				
				return
			
			_set_camera_positions(
				Vector3(
					x + level_parent_starting_point.x + level_parent_position.x + 0.5,
					camera_height,
					z + level_parent_starting_point.z + level_parent_position.z + 0.5 - 1.0
				)
			)
			
			await get_tree().process_frame
			
			# Populate image with scanned colors
			for map_viewport in map_generator_viewports:
				_fill_rectangle_on_map_image(map_viewport, x, z)
	
	# Reset camera position
	_set_camera_positions(Vector3(0.0, camera_height, 0.0))
	
	# Build image path
	var image_path: String = image_directory.path_join('map_' + level_parent.get_name() + '.png')
	
	# Save map image
	map_image.save_png(image_path)
	
	await get_tree().process_frame
	
	# Refresh map image so we can instantly check out the results
	_refresh_file(image_path)
	
	# Clear viewports from the addon's tree
	_clear_viewports()
	
	# Restore update_continuously back to initial state
	_set_update_continuously_setting(initial_update_continuously)
	
	# Final messages
	_print_message('Map generated successfully.', 'green')
	_print_message("Don't forget to remove NapMapGenerator from your scene tree!", 'yellow')

## Fills a rectangle with the sampled color on the [member NapMapGenerator.map_image].
func _fill_rectangle_on_map_image(viewport: MapGeneratorViewport, x: int, y: int) -> void:
	var map_viewport_index: int = viewport.get_index()
	var sample_color: Color = _sampleViewForColor(viewport)
	var pixel_rectangle: Rect2i = Rect2i(
		Vector2i(floori(x), floori(y + map_viewport_index)) * map_scale,
		Vector2i(map_scale, map_scale)
	)
	
	map_image.fill_rect(pixel_rectangle, sample_color)

func _get_update_continuously_setting() -> bool:
	return EditorInterface.get_editor_settings().get_setting('interface/editor/update_continuously')

## Sets update_contiuously editor setting. This is useful for when users want to
## switch to other software while waiting for the map to generate, while still
## maintaining consistent results. 
func _set_update_continuously_setting(state: bool) -> void:
	EditorInterface.get_editor_settings().set_setting('interface/editor/update_continuously', state)

## Instantly refreshes the file in the editor.
func _refresh_file(path: String) -> void:
	if (ResourceLoader.exists(path)):
		EditorInterface.get_resource_filesystem().reimport_files([path])
	else:
		EditorInterface.get_resource_filesystem().scan()

## Prints welcome message at the beginning of the scan.
func _print_welcome_message() -> void:
	_print_message("
		============ NAP Map Generator ============
		Thank you for choosing NAP Map Generator!
		Found an issue? Start a discussion on the addon's Github!
		GitHub: [url]https://github.com/NAPSoftworks/nap_map_generator[/url]
		============== NAP Softworks ==============
		",
		'orange'
	)

## Prints message with given color.
func _print_message(message: String, color: String) -> void:
	print_rich("[p][color=" + color + "]" + message + "[/color][/p]".dedent())

## Clears all the viewports currently in the scene.
func _clear_viewports() -> void:
		for child in get_children():
			child.queue_free()
		
		map_generator_viewports.clear()

## Populates viewports with the amount of viewports specified in
## [member NapMapGenerator.simulatenous_rows].
func _populate_viewports() -> void:
		_clear_viewports()
		
		await get_tree().process_frame
		
		var new_viewports: Array[MapGeneratorViewport] = []
		
		for row in simulatenous_rows:
			var map_generator_viewport: MapGeneratorViewport = map_generator_viewport_scene.instantiate()
			
			add_child(map_generator_viewport, true)
			map_generator_viewport.owner = get_tree().edited_scene_root
			
			await get_tree().process_frame
			
			map_generator_viewport.set_position(Vector3(0.0, camera_height, map_generator_viewport.get_index()))
			
			new_viewports.append(map_generator_viewport)
		
		map_generator_viewports = new_viewports

## Calculates bounding box of your 3D world. 
func _calculate_aabb() -> AABB:
	var aabb: AABB
	
	var children: Array[Node] = level_parent.find_children('*', 'VisualInstance3D', true, true)
	
	for child in children:
		aabb = aabb.merge(child.global_transform * child.get_aabb())
	
	return aabb

## Samples viewport cameras for average color.
func _sampleViewForColor(map_viewport: MapGeneratorViewport) -> Color:
	var view_image: Image = map_viewport.get_texture().get_image()
	var image_size: Vector2i = view_image.get_size()
	
	var colors: Array[Color] = []
	
	for y in image_size.y:
		for x in image_size.x:
			var color: Color = view_image.get_pixel(x, y)
			
			colors.append(color)
	
	return _get_average_color(colors)

## Gets an average color out of an array of colors.
func _get_average_color(colors: Array[Color]) -> Color:
	var colors_size: int = colors.size()
	var red: float = 0.0
	var green: float = 0.0
	var blue: float = 0.0
	var alpha: float = 0.0
	
	for color in colors:
		red += color.r
		green += color.g
		blue += color.b
		alpha += color.a
	
	# Make average
	red = red / colors_size
	green = green / colors_size
	blue = blue / colors_size
	alpha = alpha / colors_size
	
	# Return averaged color
	return Color(red, green, blue, alpha)

## Sets position for all the viewport cameras available.
func _set_camera_positions(new_position: Vector3) -> void:
	for map_viewport in map_generator_viewports:
		new_position.z += 1
		
		map_viewport.set_position(new_position)
