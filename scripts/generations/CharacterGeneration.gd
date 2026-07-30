extends Node

const WORLD_FILE_PATH = "res://data/static/world.json"
const NAME_FILE_PATH = "res://data/static/name.json"
const TEMPLATE_FILE_PATH = "res://data/templates/character_template.json"
const CHARACTER_FILE_PATH = "res://data/player/active/character.json"

@export var characters_to_generate: int = 5

@onready var gd_llama = $"../GDLlama"
@onready var generate_button = $"../Button" # Adjust path to your UI Button if needed

var _is_generating: bool = false

func _ready() -> void:
	gd_llama.generate_text_finished.connect(_on_generation_finished)

func generate_character_batch(amount: int) -> void:
	# Prevent overlapping calls if already busy processing
	if _is_generating:
		print("Generation already in progress. Please wait...")
		return
		
	_is_generating = true
	
	# Optionally disable the button visually in your UI while working
	if generate_button:
		generate_button.disabled = true

	var world_data = _load_json_file(WORLD_FILE_PATH)
	var name_data = _load_json_file(NAME_FILE_PATH)
	var template_data = _load_json_file(TEMPLATE_FILE_PATH)
	
	if world_data == null or name_data == null or template_data == null:
		_reset_generation_state()
		return

	var allowed_ethnicities = ["indonesia", "dutch", "japanese", "indo_european", "chinese_indonesian"]
	var allowed_given_names: Array = []
	var allowed_family_names: Array = []

	if name_data.has("name_styles"):
		for style in name_data["name_styles"]:
			if style["id"] in allowed_ethnicities:
				for g_male in style["given_names"]["male"]:
					if not allowed_given_names.has(g_male): allowed_given_names.append(g_male)
				for g_fem in style["given_names"]["female"]:
					if not allowed_given_names.has(g_fem): allowed_given_names.append(g_fem)
				for f_name in style["family_names"]:
					if not allowed_family_names.has(f_name): allowed_family_names.append(f_name)

	var character_schema: Dictionary = {
		"type": "array",
		"minItems": amount,
		"maxItems": amount,
		"items": {
			"type": "object",
			"properties": {
				"given_name": { "type": "string", "enum": allowed_given_names },
				"family_name": { "type": "string", "enum": allowed_family_names },
				"gender": { "type": "string", "enum": ["male", "female"] },
				"birth_year": { "type": "integer" },
				"description": { "type": "string" }
			},
			"required": [
				"given_name", "family_name", "gender", 
				"birth_year", "description"
			]
		}
	}
	
	var schema_string = JSON.stringify(character_schema)
	
	var prompt: String = "CRITICAL: Output ONLY a raw JSON array. No markdown, no explanations.\n"
	prompt += "Generate exactly " + str(amount) + " distinct character profiles based on the 1940s Indonesia setting.\n"
	prompt += "Keep the description concise (1-2 sentences) reflecting historical context.\n\n"
	prompt += "World Data context: " + JSON.stringify(world_data) + "\n\n"
	prompt += "Name Pools context: " + JSON.stringify(name_data) + "\n\n"
	prompt += "Required Template structure per character: " + JSON.stringify(template_data)
	
	gd_llama.run_generate_text(prompt, "", schema_string)

func _on_generation_finished(generated_text: String) -> void:
	var characters: Array = []
	var next_index: int = 0
	
	if FileAccess.file_exists(CHARACTER_FILE_PATH):
		var read_file = FileAccess.open(CHARACTER_FILE_PATH, FileAccess.READ)
		var content = read_file.get_as_text().strip_edges()
		read_file.close()
		
		if not content.is_empty():
			var parsed_data = JSON.parse_string(content)
			if typeof(parsed_data) == TYPE_ARRAY:
				characters = parsed_data
			elif parsed_data != null:
				characters.append(parsed_data)
				
	for char_entry in characters:
		var char_id = char_entry.get("id", "")
		if char_id.begins_with("CH-"):
			var idx_str = char_id.trim_prefix("CH-")
			if idx_str.is_valid_int():
				var idx = idx_str.to_int()
				if idx >= next_index:
					next_index = idx + 1
				
	var json_start = generated_text.find("[")
	var json_end = generated_text.rfind("]")
	
	if json_start != -1 and json_end != -1 and json_end > json_start:
		var clean_json_string = generated_text.substr(json_start, json_end - json_start + 1)
		var new_characters = JSON.parse_string(clean_json_string)
		
		if typeof(new_characters) == TYPE_ARRAY:
			for i in range(new_characters.size()):
				var char_dict = new_characters[i]
				
				var g_name = char_dict.get("given_name", "")
				var f_name = char_dict.get("family_name", "")
				if f_name == "":
					char_dict["name"] = g_name
				else:
					char_dict["name"] = g_name + " " + f_name
				
				char_dict.erase("given_name")
				char_dict.erase("family_name")
				
				char_dict["id"] = "CH-" + str(next_index + i)
				characters.append(char_dict)
			
			var write_file = FileAccess.open(CHARACTER_FILE_PATH, FileAccess.WRITE)
			write_file.store_string(JSON.stringify(characters, "\t"))
			write_file.close()

	_reset_generation_state()

func _reset_generation_state() -> void:
	_is_generating = false
	if generate_button:
		generate_button.disabled = false

func _load_json_file(file_path: String):
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var content = file.get_as_text()
		file.close()
		return JSON.parse_string(content)
	return null

func _on_button_pressed() -> void:
	generate_character_batch(characters_to_generate)
