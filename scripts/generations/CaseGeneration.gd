extends Node

signal case_ready(case_data: Dictionary)

const CASE_TYPE_FILE_PATH = "res://data/static/case_type/case_type.json"
const LEGACY_CASE_TYPE_FILE_PATH = "res://data/static/case_type.json"
const WORLD_FILE_PATH = "res://data/static/world.json"
const CASE_TEMPLATE_PATH = "res://data/static/case_type/case_template.json"
const LEGACY_CASE_TEMPLATE_PATH = "res://data/templates/case_template.json"

@onready var gd_llama = $"../GDLlama"

var _is_busy: bool = false
var _pending_target_character: Dictionary = {}

func _ready() -> void:
	if gd_llama and not gd_llama.generate_text_finished.is_connected(_on_generation_finished):
		gd_llama.generate_text_finished.connect(_on_generation_finished)

func generate_case_for_character(character_data: Dictionary) -> void:
	if _is_busy:
		return
	_is_busy = true
	_pending_target_character = character_data

	var rng = RandomNumberGenerator.new()
	rng.randomize()

	var case_types_list = _load_json_array_from_key(CASE_TYPE_FILE_PATH, "case_types")
	var chosen_case_type = "identity_verification"
	if not case_types_list.is_empty():
		chosen_case_type = case_types_list[rng.randi_range(0, case_types_list.size() - 1)]

	var char_name = character_data.get("name", "Local Resident")

	var system_prompt = "You are an administrative records clerk in 1940s Indonesia. Write exactly two concise sentences in plain prose describing the administrative dispute or discrepancy. Return only the scenario text. No markdown, no bullets, no labels, no quotes, and no meta-commentary."
	var prompt = "Case scenario for %s under case type '%s'. Return only the scenario description." % [char_name, chosen_case_type]
	var full_prompt = "%s\n\n%s" % [system_prompt, prompt]

	if gd_llama:
		gd_llama.context_size = 1024 # Constrain memory usage to prevent OOM
		gd_llama.n_predict = 256
		gd_llama.temperature = 0.5
		gd_llama.top_p = 0.9
		gd_llama.top_k = 40
		
		gd_llama.run_generate_text(full_prompt, "", "")
	else:
		_on_generation_finished("An administrative dispute has been logged regarding " + char_name + " concerning a conflict in historical records.")

func _on_generation_finished(generated_text: String) -> void:
	_is_busy = false
	var raw_text = generated_text.strip_edges() if generated_text else ""
	raw_text = _sanitize_generated_text(raw_text)
	
	var char_name = "Local Resident"
	if not _pending_target_character.is_empty() and _pending_target_character.has("name"):
		char_name = str(_pending_target_character["name"])
	
	var lower_text = raw_text.to_lower()
	if "failed to initialize sampling subsystem" in raw_text or "unable to load model" in raw_text or raw_text.length() < 15 or lower_text.contains("human:") or lower_text.contains("assistant:"):
		raw_text = "An administrative dispute has been logged regarding " + char_name + " concerning a conflict in historical records. The player must review the attached documents to verify the validity of the claim."

	var desc = raw_text
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var deadline_days = rng.randi_range(3, 14)

	var template = _load_json_file(CASE_TEMPLATE_PATH)
	if typeof(template) != TYPE_DICTIONARY:
		template = {
			"id": "",
			"title": "",
			"case_type": "",
			"requester": {"character_name": "", "reason": ""},
			"description": "",
			"documents": [],
			"deadline": 0,
			"resolution": {"correct_decision": "", "explanation": ""}
		}

	template["title"] = "Case File - " + char_name
	
	var case_types_list = _load_json_array_from_key(CASE_TYPE_FILE_PATH, "case_types")
	var assigned_type = "identity_verification"
	if not case_types_list.is_empty():
		rng.randomize()
		assigned_type = case_types_list[rng.randi_range(0, case_types_list.size() - 1)]
	template["case_type"] = assigned_type

	template["description"] = desc
	template["deadline"] = deadline_days
	
	if not template.has("requester") or typeof(template["requester"]) != TYPE_DICTIONARY:
		template["requester"] = {}
	template["requester"]["character_name"] = char_name
	template["requester"]["reason"] = "Mandatory administrative validation under 1940s records compliance for " + char_name + "."

	template["documents"] = _get_strictly_validated_documents(assigned_type)

	rng.randomize()
	var is_approved = rng.randf() > 0.5
	if not template.has("resolution") or typeof(template["resolution"]) != TYPE_DICTIONARY:
		template["resolution"] = {}
	if is_approved:
		template["resolution"]["correct_decision"] = "approve"
		template["resolution"]["explanation"] = "All paper records, seals, and handwriting metrics for " + char_name + " match official district archives."
	else:
		template["resolution"]["correct_decision"] = "reject"
		template["resolution"]["explanation"] = "Significant discrepancies, invalid authorization seals, or conflicting registry dates detected in files for " + char_name + "."

	_pending_target_character.clear()
	case_ready.emit(template)

func _sanitize_generated_text(raw_text: String) -> String:
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
	cleaned = cleaned.strip_edges()

	var lower = cleaned.to_lower()
	if lower.contains("human:") or lower.contains("assistant:") or lower.contains("answer") or lower.contains("output:"):
		return ""

	var first_period = cleaned.find(".")
	var first_excl = cleaned.find("!")
	var first_quest = cleaned.find("?")
	var cut_pos = -1
	for pos in [first_period, first_excl, first_quest]:
		if pos != -1 and (cut_pos == -1 or pos < cut_pos):
			cut_pos = pos
	if cut_pos != -1:
		cleaned = cleaned.substr(0, cut_pos + 1).strip_edges()
	return cleaned

func _get_strictly_validated_documents(case_type: String) -> Array:
	var core_docs = []
	var lower_case = case_type.to_lower()
	
	if lower_case.contains("nationality") or lower_case.contains("citizen"):
		core_docs = ["citizenship_certificate", "residency_certificate"]
	elif lower_case.contains("identity") or lower_case.contains("name"):
		core_docs = ["official_notice", "residency_certificate"]
	elif lower_case.contains("land") or lower_case.contains("property") or lower_case.contains("boundary"):
		core_docs = ["ownership_record", "land_record"]
	elif lower_case.contains("employment") or lower_case.contains("business") or lower_case.contains("tax"):
		core_docs = ["employment_record", "employment_contract", "tax_record"]
	elif lower_case.contains("religious") or lower_case.contains("marriage") or lower_case.contains("birth"):
		core_docs = ["birth_record", "marriage_record"]
	elif lower_case.contains("education") or lower_case.contains("school") or lower_case.contains("student"):
		core_docs = ["student_record", "academic_certificate"]
	elif lower_case.contains("medical") or lower_case.contains("health"):
		core_docs = ["medical_record", "medical_certificate"]
	elif lower_case.contains("security") or lower_case.contains("investigation"):
		core_docs = ["investigation_report", "witness_statement"]
	else:
		core_docs = ["official_notice", "administrative_report"]

	var all_possible_docs = []
	var institutions = _load_json_array_from_key(WORLD_FILE_PATH, "institutions")
	if institutions.is_empty():
		var raw_world = _load_json_file(WORLD_FILE_PATH)
		if typeof(raw_world) == TYPE_DICTIONARY and raw_world.has("institutions"):
			institutions = raw_world["institutions"]
		elif typeof(raw_world) == TYPE_ARRAY:
			institutions = raw_world

	for inst in institutions:
		for timeline in inst.get("timeline", []):
			for dtype in timeline.get("document_types", []):
				if not all_possible_docs.has(dtype):
					all_possible_docs.append(dtype)

	if all_possible_docs.is_empty():
		all_possible_docs = ["official_notice", "personal_letter", "diary_entry", "tax_record", "report"]

	var rng = RandomNumberGenerator.new()
	rng.randomize()

	var noise_pool = []
	for dtype in all_possible_docs:
		if not core_docs.has(dtype):
			noise_pool.append(dtype)

	noise_pool.shuffle()
	var num_noise = rng.randi_range(3, 5)
	var chosen_noise = []
	for i in range(min(num_noise, noise_pool.size())):
		chosen_noise.append(noise_pool[i])

	var final_documents = []
	final_documents.append_array(core_docs)
	final_documents.append_array(chosen_noise)

	for core in core_docs:
		if not final_documents.has(core):
			final_documents.append(core)

	final_documents.shuffle()
	return final_documents

func _load_json_array_from_key(path: String, key: String) -> Array:
	var candidate_paths = [path]
	if path != LEGACY_CASE_TYPE_FILE_PATH:
		candidate_paths.append(LEGACY_CASE_TYPE_FILE_PATH)

	for candidate_path in candidate_paths:
		if FileAccess.file_exists(candidate_path):
			var f = FileAccess.open(candidate_path, FileAccess.READ)
			if f != null:
				var parsed = JSON.parse_string(f.get_as_text())
				f.close()
				if typeof(parsed) == TYPE_DICTIONARY and parsed.has(key) and typeof(parsed[key]) == TYPE_ARRAY:
					return parsed[key]
	return []

func _load_json_file(path: String):
	var candidate_paths = [path]
	if path != LEGACY_CASE_TEMPLATE_PATH:
		candidate_paths.append(LEGACY_CASE_TEMPLATE_PATH)

	for candidate_path in candidate_paths:
		if FileAccess.file_exists(candidate_path):
			var f = FileAccess.open(candidate_path, FileAccess.READ)
			if f != null:
				var res = JSON.parse_string(f.get_as_text())
				f.close()
				return res
	return null
