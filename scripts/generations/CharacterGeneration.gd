extends Node

const CHARACTER_FILE_PATH = "res://data/player/active/character.json"
const NAME_FILE_PATH = "res://data/static/name.json"

@export var target_total_characters: int = 25

@onready var gd_llama = $"../GDLlama"
@onready var generate_button = $"../Button"

var _is_generating: bool = false
var _pending_character: Dictionary = {}

func _ready() -> void:
	if gd_llama and not gd_llama.generate_text_finished.is_connected(_on_generation_finished):
		gd_llama.generate_text_finished.connect(_on_generation_finished)

func start_batch_generation() -> void:
	if _is_generating:
		return
	_is_generating = true
	if generate_button:
		generate_button.disabled = true
	_process_next_character()

func _process_next_character() -> void:
	if _get_current_character_count() >= target_total_characters:
		_is_generating = false
		if generate_button:
			generate_button.disabled = false
		return
	
	var name_data = _load_json_file(NAME_FILE_PATH)
	var name_styles = []
	if typeof(name_data) == TYPE_DICTIONARY and name_data.has("name_styles"):
		var styles_val = name_data["name_styles"]
		if typeof(styles_val) == TYPE_ARRAY:
			name_styles = styles_val

	if name_styles.is_empty():
		name_styles = [{
			"id": "indonesia",
			"format": "given_family",
			"given_names": { "male": ["Budi", "Hendra"], "female": ["Siti", "Ani"] },
			"family_names": ["Santoso", "Gunawan"]
		}]

	var rng = RandomNumberGenerator.new()
	rng.randomize()

	var chosen_ethnicity = "indonesia"
	if rng.randf() > 0.70:
		var minority = ["dutch", "japanese", "indo_european", "chinese_indonesian"]
		chosen_ethnicity = minority[rng.randi_range(0, minority.size() - 1)]

	var style = null
	for s in name_styles:
		if typeof(s) == TYPE_DICTIONARY and s.get("id", "") == chosen_ethnicity:
			style = s
			break
	if style == null:
		style = name_styles[0]

	var gender = "male" if rng.randf() > 0.5 else "female"
	
	var given_pool = []
	if typeof(style) == TYPE_DICTIONARY and style.has("given_names"):
		var g_dict = style["given_names"]
		if typeof(g_dict) == TYPE_DICTIONARY:
			var key = "male" if gender == "male" else "female"
			if g_dict.has(key) and typeof(g_dict[key]) == TYPE_ARRAY:
				given_pool = g_dict[key]

	if given_pool.is_empty():
		given_pool = ["Ahmad"] if gender == "male" else ["Siti"]

	var given_name = given_pool[rng.randi_range(0, given_pool.size() - 1)]
	
	var family_pool = []
	if typeof(style) == TYPE_DICTIONARY and style.has("family_names"):
		var f_val = style["family_names"]
		if typeof(f_val) == TYPE_ARRAY:
			family_pool = f_val

	var family_name = ""
	if not family_pool.is_empty():
		family_name = family_pool[rng.randi_range(0, family_pool.size() - 1)]

	var name_format = "given_family"
	if typeof(style) == TYPE_DICTIONARY and style.has("format"):
		name_format = str(style["format"])

	var full_name = given_name
	if not family_name.is_empty():
		if name_format == "given_family":
			full_name = given_name + " " + family_name
		else:
			full_name = family_name + " " + given_name

	_pending_character = {
		"name": full_name,
		"gender": gender,
		"ethnicity": chosen_ethnicity
	}

	# Use a completion-style prompt to stop the model from treating it like a chat command
	var completion_prompt = "Historical profile of " + full_name + " (" + gender + ", " + chosen_ethnicity + ") in 1940s Indonesia:\n- Description: " + full_name + " was"

	if gd_llama:
		gd_llama.run_generate_text(completion_prompt, "", "")
	else:
		_on_generation_finished("a local resident navigating daily life in 1940s Indonesia.")

func _get_current_character_count() -> int:
	if not FileAccess.file_exists(CHARACTER_FILE_PATH):
		return 0
	var read_file = FileAccess.open(CHARACTER_FILE_PATH, FileAccess.READ)
	if read_file == null:
		return 0
	var c = read_file.get_as_text().strip_edges()
	read_file.close()
	if c.is_empty():
		return 0
	var p = JSON.parse_string(c)
	if typeof(p) == TYPE_ARRAY:
		return p.size()
	elif p != null:
		return 1
	return 0

func _on_generation_finished(generated_text: String) -> void:
	var raw_text = generated_text.strip_edges() if generated_text else ""
	
	# Since our prompt ends with "Name was", we prepend it back if the model didn't echo it
	var desc = ""
	var name = _pending_character.get("name", "The resident")
	if not raw_text.begins_with(name):
		desc = name + " was " + raw_text
	else:
		desc = raw_text

	# Anti-Bleeding & Meta-Talk Filter
	var lower_desc = desc.to_lower()
	if lower_desc.contains("no more") or lower_desc.contains("human:") or lower_desc.contains("assistant:") or lower_desc.contains("translate"):
		desc = name + " was a local resident navigating daily life in 1940s Indonesia."

	# Force strict one-sentence truncation
	var first_period = desc.find(".")
	var first_excl = desc.find("!")
	var first_quest = desc.find("?")
	
	var cut_pos = -1
	for pos in [first_period, first_excl, first_quest]:
		if pos != -1 and (cut_pos == -1 or pos < cut_pos):
			cut_pos = pos
			
	if cut_pos != -1:
		desc = desc.substr(0, cut_pos + 1).strip_edges()

	if desc.is_empty() or desc.length() < 8:
		desc = name + " was a local resident navigating daily life in 1940s Indonesia."

	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var birth_date_str = "%d-%02d-%02d" % [rng.randi_range(1900, 1925), rng.randi_range(1, 12), rng.randi_range(1, 28)]

	var characters = []
	var next_index = 0
	if FileAccess.file_exists(CHARACTER_FILE_PATH):
		var read_file = FileAccess.open(CHARACTER_FILE_PATH, FileAccess.READ)
		if read_file != null:
			var p = JSON.parse_string(read_file.get_as_text().strip_edges())
			read_file.close()
			if typeof(p) == TYPE_ARRAY:
				characters = p
			elif p != null:
				characters.append(p)

	for ch in characters:
		if typeof(ch) == TYPE_DICTIONARY:
			var cid = ch.get("id", "")
			if cid is String and cid.begins_with("CH-"):
				var idx = cid.trim_prefix("CH-").to_int()
				if idx >= next_index:
					next_index = idx + 1

	characters.append({
		"id": "CH-%d" % next_index,
		"name": name,
		"gender": _pending_character.get("gender", "male"),
		"ethnicity": _pending_character.get("ethnicity", "indonesia"),
		"birth_date": birth_date_str,
		"description": desc
	})

	var write_file = FileAccess.open(CHARACTER_FILE_PATH, FileAccess.WRITE)
	if write_file != null:
		write_file.store_string(JSON.stringify(characters, "\t"))
		write_file.close()

	_pending_character.clear()
	_process_next_character()

func _load_json_file(path: String):
	if FileAccess.file_exists(path):
		var read_file = FileAccess.open(path, FileAccess.READ)
		if read_file != null:
			var text = read_file.get_as_text()
			read_file.close()
			return JSON.parse_string(text)
	return null

func _on_button_pressed() -> void:
	start_batch_generation()