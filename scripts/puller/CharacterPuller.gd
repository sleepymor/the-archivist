extends Node

const POOL_FILE_PATH = "res://data/storage/character_pool.json"
const ACTIVE_FILE_PATH = "res://data/player/active/character.json"

const CASE_POOL_FILE_PATH = "res://data/storage/case_pool.json"
const ACTIVE_CASE_FILE_PATH = "res://data/player/active/case.json"

@export var pull_chance: float = 1.0
@export var watcher_node_path: NodePath

@onready var watcher_node = get_node_or_null(watcher_node_path)

func _ready() -> void:
	# Automatically find the Button node located alongside this node and connect it via code
	var pull_btn = get_node_or_null("../Button")
	if pull_btn and pull_btn is Button:
		if not pull_btn.pressed.is_connected(_on_pull_button_pressed):
			pull_btn.pressed.connect(_on_pull_button_pressed)
			print("CharacterPuller: Successfully auto-connected to Button.pressed() via code!")
	else:
		print("CharacterPuller Warning: Could not find '../Button' node in the scene tree.")

func pull_character_package() -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	if rng.randf() > pull_chance:
		print("Puller Debug: Pull skipped due to pull_chance probability.")
		return {}

	var character_pool = _filter_valid_character_pool(_load_json_array(POOL_FILE_PATH))
	var case_pool = _filter_valid_case_pool(_load_json_array(CASE_POOL_FILE_PATH))

	print("Puller Debug: Character pool count = %d | Case pool count = %d" % [character_pool.size(), case_pool.size()])

	if character_pool.is_empty() or case_pool.is_empty():
		print("Puller Debug: Pools are not ready yet. Triggering watcher check...")
		if watcher_node and watcher_node.has_method("check_pool"):
			watcher_node.check_pool()
		return {}

	var pulled_char = character_pool.pop_front()
	var pulled_case = case_pool.pop_front()

	_save_json_array(POOL_FILE_PATH, character_pool)
	_save_json_array(CASE_POOL_FILE_PATH, case_pool)

	var active_chars = _load_json_array(ACTIVE_FILE_PATH)
	var next_char_index = _get_next_index(active_chars, "id", "CH-")
	pulled_char["id"] = "CH-%d" % next_char_index
	active_chars.append(pulled_char)
	_save_json_array(ACTIVE_FILE_PATH, active_chars)

	var active_cases = _load_json_array(ACTIVE_CASE_FILE_PATH)
	var next_case_index = _get_next_index(active_cases, "active_ref_id", "CS-ACT-")
	pulled_case["active_ref_id"] = "CS-ACT-%d" % next_case_index
	active_cases.append(pulled_case)
	_save_json_array(ACTIVE_CASE_FILE_PATH, active_cases)

	print("SUCCESS Package Pulled: Character [%s] paired with Case [%s]" % [pulled_char["name"], pulled_case["title"]])
	
	if watcher_node and watcher_node.has_method("check_pool"):
		watcher_node.check_pool()
		
	return { "character": pulled_char, "case": pulled_case }

func _filter_valid_character_pool(pool: Array) -> Array:
	var valid_pool = []
	for item in pool:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var name = str(item.get("name", "")).strip_edges()
		var desc = str(item.get("description", "")).strip_edges()
		if name.is_empty() or name == "The resident" or desc.to_lower().contains("### answer") or desc.to_lower().contains("answer:"):
			continue
		valid_pool.append(item)
	return valid_pool

func _filter_valid_case_pool(pool: Array) -> Array:
	var valid_pool = []
	for item in pool:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var title = str(item.get("title", "")).strip_edges()
		var desc = str(item.get("description", "")).strip_edges()
		if title.is_empty() or title.contains("The resident") or desc.to_lower().contains("### answer") or desc.to_lower().contains("answer:"):
			continue
		valid_pool.append(item)
	return valid_pool

func _load_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var read_file = FileAccess.open(path, FileAccess.READ)
	if read_file == null:
		return []
	var content = read_file.get_as_text().strip_edges()
	read_file.close()
	if content.is_empty():
		return []
	var parsed = JSON.parse_string(content)
	if typeof(parsed) == TYPE_ARRAY:
		return parsed
	elif parsed != null:
		return [parsed]
	return []

func _save_json_array(path: String, array: Array) -> void:
	var dir_path = path.get_base_dir()
	var dir = DirAccess.open("res://")
	if dir != null:
		if not dir.dir_exists(dir_path):
			dir.make_dir_recursive(dir_path)

	var write_file = FileAccess.open(path, FileAccess.WRITE)
	if write_file != null:
		write_file.store_string(JSON.stringify(array, "\t"))
		write_file.close()

func _get_next_index(array: Array, key: String, prefix: String) -> int:
	var next_index = 0
	for item in array:
		if typeof(item) == TYPE_DICTIONARY:
			var cid = item.get(key, "")
			if cid is String and cid.begins_with(prefix):
				var idx = cid.trim_prefix(prefix).to_int()
				if idx >= next_index:
					next_index = idx + 1
	return next_index

func _on_pull_button_pressed() -> void:
	print("BUTTON CLICKED: _on_pull_button_pressed was triggered!")
	pull_character_package()
