extends Node

const POOL_FILE_PATH = "res://data/storage/character_pool.json"
const CASE_POOL_FILE_PATH = "res://data/storage/case_pool.json"

@export var target_pool_size: int = 50
@export var background_check_interval: float = 2.0
@export var generator_node_path: NodePath
@export var case_generator_node_path: NodePath

@onready var generator = get_node_or_null(generator_node_path)
@onready var case_generator = get_node_or_null(case_generator_node_path)

var _is_busy: bool = false
var _check_timer: Timer = null

func _ready() -> void:
	if generator and not generator.is_connected("character_ready", _on_character_generated):
		generator.connect("character_ready", _on_character_generated)
				
	if case_generator and not case_generator.is_connected("case_ready", _on_case_generated):
		case_generator.connect("case_ready", _on_case_generated)
	
	_validate_and_fix_pools()
	_trim_pools_to_target()
	_create_background_timer()
	call_deferred("check_pool")

func _create_background_timer() -> void:
	_check_timer = Timer.new()
	_check_timer.wait_time = background_check_interval
	_check_timer.one_shot = false
	_check_timer.autostart = true
	add_child(_check_timer)
	_check_timer.timeout.connect(Callable(self, "_on_background_check"))

func _on_background_check() -> void:
	if not _is_busy:
		check_pool()

func _validate_and_fix_pools() -> void:
	var char_pool = _load_json_array(POOL_FILE_PATH)
	var case_pool = _load_json_array(CASE_POOL_FILE_PATH)
	var fixed = false
	
	for i in range(min(char_pool.size(), case_pool.size())):
		var char_item = char_pool[i]
		var case_item = case_pool[i]
		
		if typeof(char_item) != TYPE_DICTIONARY or typeof(case_item) != TYPE_DICTIONARY:
			continue
			
		var char_name = char_item.get("name", "")
		if char_name.is_empty():
			continue
			
		var expected_title = "Case File - " + char_name
		
		if case_item.get("title", "") != expected_title or case_item.get("title", "").contains("Local Resident"):
			case_item["title"] = expected_title
			fixed = true
			
		if not case_item.has("requester") or typeof(case_item["requester"]) != TYPE_DICTIONARY:
			case_item["requester"] = {}
			
		if case_item["requester"].get("character_name", "") != char_name:
			case_item["requester"]["character_name"] = char_name
			case_item["requester"]["reason"] = "Mandatory administrative validation under 1940s records compliance for " + char_name + "."
			fixed = true
		
		if case_item.has("resolution") and typeof(case_item["resolution"]) == TYPE_DICTIONARY:
			var expl = case_item["resolution"].get("explanation", "")
			if expl.contains("Local Resident"):
				if case_item["resolution"].get("correct_decision") == "approve":
					case_item["resolution"]["explanation"] = "All paper records, seals, and handwriting metrics for " + char_name + " match official district archives."
				else:
					case_item["resolution"]["explanation"] = "Significant discrepancies, invalid authorization seals, or conflicting registry dates detected in files for " + char_name + "."
				fixed = true

	if fixed:
		_save_json_array(CASE_POOL_FILE_PATH, case_pool)
		print("Pool Validator: Corrected name mismatches in case pool items to match character pool indices.")

func _trim_pools_to_target() -> void:
	var char_pool = _load_json_array(POOL_FILE_PATH)
	var cleaned_char_pool = []
	for item in char_pool:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var name = str(item.get("name", "")).strip_edges()
		var desc = str(item.get("description", "")).strip_edges()
		if name.is_empty() or name == "The resident" or desc.to_lower().contains("### answer"):
			continue
		cleaned_char_pool.append(item)
	if cleaned_char_pool.size() > target_pool_size:
		cleaned_char_pool = cleaned_char_pool.slice(0, target_pool_size)
	if cleaned_char_pool.size() != char_pool.size():
		_save_json_array(POOL_FILE_PATH, cleaned_char_pool)
		print("Pool Watcher: Purged invalid character pool entries.")

	var case_pool = _load_json_array(CASE_POOL_FILE_PATH)
	var cleaned_case_pool = []
	for item in case_pool:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var title = str(item.get("title", "")).strip_edges()
		var desc = str(item.get("description", "")).strip_edges()
		if title.is_empty() or title.contains("The resident") or desc.to_lower().contains("### answer"):
			continue
		cleaned_case_pool.append(item)
	if cleaned_case_pool.size() > target_pool_size:
		cleaned_case_pool = cleaned_case_pool.slice(0, target_pool_size)
	if cleaned_case_pool.size() != case_pool.size():
		_save_json_array(CASE_POOL_FILE_PATH, cleaned_case_pool)
		print("Pool Watcher: Purged invalid case pool entries.")

func check_pool() -> void:
	if _is_busy:
		return
	
	_trim_pools_to_target()
	var char_pool = _load_json_array(POOL_FILE_PATH)
	var case_pool = _load_json_array(CASE_POOL_FILE_PATH)
	
	# Phase 1: Fill Character Pool Completely First
	if char_pool.size() < target_pool_size:
		_is_busy = true
		print("Pool Watcher [Phase 1]: Generating character %d/%d..." % [char_pool.size() + 1, target_pool_size])
		if generator and generator.has_method("generate_character"):
			generator.generate_character()
		else:
			_is_busy = false
			print("Pool Watcher Error: CharacterGenerator node missing.")
		return

	# Phase 2: Strict block - do not proceed to cases if character pool is empty or not full
	if char_pool.is_empty() or char_pool.size() < target_pool_size:
		_is_busy = false
		return

	# Phase 3: Fill Case Pool Sequentially one by one up to character pool size
	if case_pool.size() < char_pool.size() and case_pool.size() < target_pool_size:
		_is_busy = true
		var target_index = case_pool.size()
		
		if target_index >= char_pool.size():
			_is_busy = false
			return
			
		var target_char = char_pool[target_index]
		print("Pool Watcher [Phase 2]: Generating case %d/%d for character: %s..." % [target_index + 1, target_pool_size, target_char.get("name", "")])
		
		if case_generator and case_generator.has_method("generate_case_for_character"):
			case_generator.generate_case_for_character(target_char)
		else:
			_is_busy = false
			print("Pool Watcher Error: CaseGenerator node missing.")
		return

	_is_busy = false

func _on_character_generated(character_data: Dictionary) -> void:
	var pool = _load_json_array(POOL_FILE_PATH)
	
	var max_index = -1
	for ch in pool:
		if typeof(ch) == TYPE_DICTIONARY and ch.has("id"):
			var cid = str(ch["id"])
			if cid.begins_with("CH-"):
				var idx = cid.trim_prefix("CH-").to_int()
				if idx > max_index:
					max_index = idx
					
	character_data["id"] = "CH-%d" % (max_index + 1)
	pool.append(character_data)
	_save_json_array(POOL_FILE_PATH, pool)
	
	_is_busy = false
	call_deferred("check_pool")

func _on_case_generated(case_data: Dictionary) -> void:
	var case_pool = _load_json_array(CASE_POOL_FILE_PATH)
	
	var max_index = -1
	for c in case_pool:
		if typeof(c) == TYPE_DICTIONARY and c.has("id"):
			var cid = str(c["id"])
			if cid.begins_with("CASE-"):
				var idx = cid.trim_prefix("CASE-").to_int()
				if idx > max_index:
					max_index = idx
					
	case_data["id"] = "CASE-%d" % (max_index + 1)
	case_pool.append(case_data)
	_save_json_array(CASE_POOL_FILE_PATH, case_pool)
	
	_validate_and_fix_pools()
	
	_is_busy = false
	call_deferred("check_pool")

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
