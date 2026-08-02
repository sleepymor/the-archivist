extends Node

signal character_ready(character_data: Dictionary)

const NAME_FILE_PATH = "res://data/static/name.json"

@onready var gd_llama = $"../GDLlama"

var _is_busy: bool = false
var _pending_character: Dictionary = {}

func _ready() -> void:
	if gd_llama and not gd_llama.generate_text_finished.is_connected(_on_generation_finished):
		gd_llama.generate_text_finished.connect(_on_generation_finished)

func generate_character() -> void:
	if _is_busy:
		return
	_is_busy = true
	
	var name_data = _load_json_file(NAME_FILE_PATH)
	var name_styles = []
	if typeof(name_data) == TYPE_DICTIONARY and name_data.has("name_styles"):
		var styles_val = name_data["name_styles"]
		if typeof(styles_val) == TYPE_ARRAY:
			name_styles = styles_val

	if name_styles.is_empty():
		name_styles = [ {
			"id": "indonesia",
			"format": "given_family",
			"given_names": {"male": ["Budi", "Hendra"], "female": ["Siti", "Ani"]},
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

	var system_prompt = "You are a strict historical biographer specializing in 1940s Indonesia. Write exactly one concise English biographical sentence about the specified individual. Return only the sentence and nothing else. Do not echo the prompt, do not repeat instructions, do not use markdown, quotes, numbering, labels, or conversational filler."
	var completion_prompt = "Profile of %s (%s, %s) in 1940s Indonesia. Return only one sentence beginning with '%s was'." % [full_name, gender, chosen_ethnicity, full_name]
	var full_prompt = "%s\n\n%s" % [system_prompt, completion_prompt]

	if gd_llama:
		gd_llama.context_size = 1024 # Constrain memory usage to prevent OOM
		gd_llama.n_predict = 256
		gd_llama.temperature = 0.5
		gd_llama.top_p = 0.9
		gd_llama.top_k = 40
		
		gd_llama.run_generate_text(full_prompt, "", "")
	else:
		_on_generation_finished("a local resident navigating daily life in 1940s Indonesia.")

func _on_generation_finished(generated_text: String) -> void:
	_is_busy = false
	var raw_text = generated_text.strip_edges() if generated_text else ""
	
	if "failed to initialize sampling subsystem" in raw_text or "unable to load model" in raw_text:
		raw_text = ""

	var desc = ""
	var name = _pending_character.get("name", "")
	if typeof(name) != TYPE_STRING:
		name = str(name)
	if name.is_empty():
		name = "The resident"

	raw_text = _sanitize_generated_sentence(raw_text)
	if not raw_text.is_empty() and name != "The resident":
		var raw_lower = raw_text.to_lower()
		if raw_lower.contains("the resident was"):
			raw_text = raw_text.replace("The resident", name)
			raw_text = raw_text.replace("the resident", name)
			raw_text = raw_text.replace("The Resident", name)
			raw_text = raw_text.replace("the Resident", name)
		if raw_lower.contains("resident") and raw_text.begins_with(name) == false:
			raw_text = raw_text.replace("the resident", name)
			raw_text = raw_text.replace("The resident", name)

	if raw_text.is_empty():
		desc = name + " was a local resident navigating daily life in 1940s Indonesia."
	elif not raw_text.begins_with(name):
		desc = name + " was " + raw_text
	else:
		desc = raw_text

	var lower_desc = desc.to_lower()
	if lower_desc.contains("no more") or lower_desc.contains("human:") or lower_desc.contains("assistant:") or lower_desc.contains("translate"):
		desc = name + " was a local resident navigating daily life in 1940s Indonesia."

	var first_period = desc.find(".")
	var first_excl = desc.find("!")
	var first_quest = desc.find("?")
	
	var cut_pos = -1
	for pos in [first_period, first_excl, first_quest]:
		if pos != -1 and (cut_pos == -1 or pos < cut_pos):
			cut_pos = pos
			
	if cut_pos != -1:
		desc = desc.substr(0, cut_pos + 1).strip_edges()

	if desc.is_empty() or desc.length() < name.length() + 8:
		desc = name + " was a local resident navigating daily life in 1940s Indonesia."

	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var birth_date_str = "%d-%02d-%02d" % [rng.randi_range(1900, 1925), rng.randi_range(1, 12), rng.randi_range(1, 28)]

	var character_data = {
		"name": name,
		"gender": _pending_character.get("gender", "male"),
		"ethnicity": _pending_character.get("ethnicity", "indonesia"),
		"birth_date": birth_date_str,
		"description": desc
	}

	_pending_character.clear()
	emit_signal("character_ready", character_data)

func _sanitize_generated_sentence(raw_text: String) -> String:
	if raw_text.is_empty():
		return ""

	var cleaned = raw_text.strip_edges()
	cleaned = cleaned.replace("\r", " ")
	cleaned = cleaned.replace("\n", " ")
	cleaned = cleaned.replace("\t", " ")
	while cleaned.find("  ") != -1:
		cleaned = cleaned.replace("  ", " ")
	cleaned = cleaned.replace("**", "")
	cleaned = cleaned.replace("###", "")
	cleaned = cleaned.replace("##", "")
	cleaned = cleaned.replace("\"", "")
	cleaned = cleaned.replace("'", "")
	cleaned = cleaned.strip_edges()

	var cleaned_lower = cleaned.to_lower()
	var junk_prefixes = [
		"biography sentence:",
		"answer:",
		"answer ",
		"solution:",
		"here is",
		"sure,",
		"as an ai",
		"output:",
		"generated text:",
		"the answer is",
		"human:",
		"assistant:"
	]
	for prefix in junk_prefixes:
		if cleaned_lower.begins_with(prefix):
			cleaned = cleaned.substr(prefix.length(), cleaned.length() - prefix.length()).strip_edges()
			cleaned_lower = cleaned.to_lower()
			break

	if cleaned.begins_with("1)"):
		cleaned = cleaned.substr(2, cleaned.length() - 2).strip_edges()
	elif cleaned.begins_with("1."):
		cleaned = cleaned.substr(2, cleaned.length() - 2).strip_edges()

	var first_period = cleaned.find(".")
	var first_excl = cleaned.find("!")
	var first_quest = cleaned.find("?")
	var cut_pos = -1
	for pos in [first_period, first_excl, first_quest]:
		if pos != -1 and (cut_pos == -1 or pos < cut_pos):
			cut_pos = pos
	if cut_pos != -1:
		cleaned = cleaned.substr(0, cut_pos + 1).strip_edges()

	if cleaned.is_empty():
		return ""
	return cleaned

func _load_json_file(path: String):
	if FileAccess.file_exists(path):
		var read_file = FileAccess.open(path, FileAccess.READ)
		if read_file != null:
			var text = read_file.get_as_text()
			read_file.close()
			return JSON.parse_string(text)
	return null
