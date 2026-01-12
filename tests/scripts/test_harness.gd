extends Node
## Universal Test Harness - Core Script
##
## Provides APIs for:
## - Dynamic scene loading
## - Input simulation
## - Screenshot capture
## - Logging

class_name TestHarness

# --- Constants ---
const LOG_DIR: String = "res://tests/logs/"
const SNAPSHOT_DIR: String = "res://tests/snapshots/"

# --- State ---
var _log_file_path: String = ""
var _loaded_scene: Node = null

# --- Lifecycle ---

func _ready() -> void:
	_initialize_log_file()
	log_info("Harness Started")
	
	# Self-verification: capture initial state and exit
	await capture_snapshot("init_state")
	log_info("Self-verification complete. Exiting.")
	get_tree().quit()


func _initialize_log_file() -> void:
	var timestamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	_log_file_path = LOG_DIR + "test_run_" + timestamp + ".txt"
	
	# Ensure log directory exists
	var dir: DirAccess = DirAccess.open("res://tests/")
	if dir and not dir.dir_exists("logs"):
		dir.make_dir("logs")
	
	# Create or overwrite log file
	var file: FileAccess = FileAccess.open(_log_file_path, FileAccess.WRITE)
	if file:
		file.store_line("[%s] Test harness initialized" % Time.get_datetime_string_from_system())
		file.close()


# --- Public API ---

## Dynamically loads a scene and adds it as a child.
## Waits two frames to ensure rendering is ready.
## Returns the instantiated node, or null on failure.
func load_test_scene(scene_path: String) -> Node:
	log_info("Loading test scene: " + scene_path)
	
	var packed_scene: PackedScene = load(scene_path) as PackedScene
	if packed_scene == null:
		log_info("ERROR: Failed to load scene: " + scene_path)
		return null
	
	_loaded_scene = packed_scene.instantiate()
	if _loaded_scene == null:
		log_info("ERROR: Failed to instantiate scene: " + scene_path)
		return null
	
	add_child(_loaded_scene)
	
	# Wait two frames to ensure rendering is ready
	await get_tree().process_frame
	await get_tree().process_frame
	
	log_info("Scene loaded successfully: " + scene_path)
	return _loaded_scene


## Simulates a mouse click at the given screen position.
## Uses Input.parse_input_event() as required by GEMINI.md.
func simulate_click(screen_position: Vector2) -> void:
	log_info("Simulating click at: " + str(screen_position))
	
	var mouse_button_event: InputEventMouseButton = InputEventMouseButton.new()
	mouse_button_event.button_index = MOUSE_BUTTON_LEFT
	mouse_button_event.position = screen_position
	mouse_button_event.global_position = screen_position
	
	# Press
	mouse_button_event.pressed = true
	Input.parse_input_event(mouse_button_event)
	
	# Release
	mouse_button_event.pressed = false
	Input.parse_input_event(mouse_button_event)


## Captures a screenshot of the current viewport.
## Saves to res://tests/snapshots/ with timestamp.
func capture_snapshot(step_name: String) -> void:
	log_info("Capturing snapshot: " + step_name)
	
	# Wait for rendering to complete
	await RenderingServer.frame_post_draw
	
	var viewport: Viewport = get_viewport()
	if viewport == null:
		log_info("ERROR: Cannot get viewport for snapshot")
		return
	
	var image: Image = viewport.get_texture().get_image()
	if image == null:
		log_info("ERROR: Cannot get image from viewport")
		return
	
	# Ensure snapshot directory exists
	var dir: DirAccess = DirAccess.open("res://tests/")
	if dir and not dir.dir_exists("snapshots"):
		dir.make_dir("snapshots")
	
	# Generate filename with timestamp
	var timestamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var filename: String = "baseline_%s_%s.png" % [step_name, timestamp]
	var save_path: String = SNAPSHOT_DIR + filename
	
	var error: Error = image.save_png(save_path)
	if error != OK:
		log_info("ERROR: Failed to save snapshot: " + str(error))
	else:
		log_info("Snapshot saved: " + save_path)


## Appends a message to the current test log file.
func log_info(message: String) -> void:
	var timestamp: String = Time.get_datetime_string_from_system()
	var formatted_message: String = "[%s] %s" % [timestamp, message]
	
	# Also print to console for debugging
	print(formatted_message)
	
	# Append to log file
	if _log_file_path.is_empty():
		return
	
	var file: FileAccess = FileAccess.open(_log_file_path, FileAccess.READ_WRITE)
	if file:
		file.seek_end()
		file.store_line(formatted_message)
		file.close()


## Returns the currently loaded test scene, or null if none.
func get_loaded_scene() -> Node:
	return _loaded_scene


## Unloads the currently loaded test scene.
func unload_test_scene() -> void:
	if _loaded_scene != null:
		log_info("Unloading test scene")
		_loaded_scene.queue_free()
		_loaded_scene = null
