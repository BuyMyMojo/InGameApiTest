extends Node3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	CLog.o("API handler active")
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_rest_api_handler_get_requested(endpoint: String, params: Dictionary, request: RESTHttpRequest, response: RESTHttpResponse) -> void:
	CLog.o("Endpoint:", endpoint)
	
	match endpoint:
		"", "/":
			response.send(200, JSON.stringify({"api routes" : {"/" : "lists all routes", "state" : "provides the state of the game"}}), "application/json")
		"/state":
			var tree: SceneTree = get_tree()
			var output = {
				"scene" : tree.current_scene.name,
				"paused" : tree.paused,
				"in_menu": "TODO",
				"menu_context" : null,
			}
			response.send(200, JSON.stringify(output, "", false), "application/json")
		"/player/info":
			pass
		"/player/location":
			response.send(200, JSON.stringify(GameQuery.get_player_location(), "", false), "application/json")


func _on_rest_http_server_no_handler_found(request: RESTHttpRequest, response: RESTHttpResponse) -> void:
	print("No handler found for path: ", request.path)
	
	response.send(
		404, 
		JSON.stringify({"status": "error", "message": "Error 404: this endpoint is not supported"}), 
		"application/json"
	)
