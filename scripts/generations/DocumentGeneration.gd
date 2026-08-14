extends Node

signal documents_ready(documents_data: Array)

const TEMPLATE_DIR = "res://data/templates/document_template/"
const WORLD_OVERVIEW_FILE_PATH = "res://data/static/world/overview.json"
const WORLD_INSTITUTIONS_FILE_PATH = "res://data/static/world/institutions.json"

@onready var gd_llama = $"../GDLlama"

var _is_busy: bool = false
var _pending_case_data: Dictionary = {}
var _pending_doc_types: Array = []
var _generated_docs: Array = []
var _current_doc_index: int = 0

func _ready() -> void:
	gd_llama.model_path = "res://models/Phi-3.5-mini-instruct-Q4_K_M.gguf"
	if gd_llama and not gd_llama.generate_text_finished.is_connected(_on_generation_finished):
		gd_llama.generate_text_finished.connect(_on_generation_finished)

func generate_documents_for_case(case_data: Dictionary) -> void:
	if _is_busy:
		return
	_is_busy = true
	_pending_case_data = case_data
	 
	var docs = case_data.get("documents", [])
	if typeof(docs) == TYPE_ARRAY:
		_pending_doc_types = docs
	else:
		_pending_doc_types = []
		
	_generated_docs.clear()
	_current_doc_index = 0

	_process_next_document()

func _process_next_document() -> void:
	if _pending_doc_types.is_empty() or _current_doc_index >= _pending_doc_types.size():
		_finalize_documents()
		return

	var dtype = _pending_doc_types[_current_doc_index]
	var requester_data = _pending_case_data.get("requester", {})
	var char_name = "Local Resident"
	if typeof(requester_data) == TYPE_DICTIONARY:
		char_name = requester_data.get("name", requester_data.get("character_name", _pending_case_data.get("character_name", "Local Resident")))
	elif typeof(requester_data) == TYPE_STRING and not requester_data.is_empty():
		char_name = requester_data

	var case_desc = _pending_case_data.get("description", "Official investigation record on file.")
	var world_context = _load_world_prompt_context()
	var world_year = int(world_context.get("year", 1942))
	var institution = str(world_context.get("institution", "District Archives Office"))

	# Determine strict language mapping based on world year / document context
	var language = "id"
	if world_year >= 1942 and world_year <= 1945:
		language = "ja"  # Japanese administration period
	elif world_year < 1942:
		language = "nl"  # Dutch colonial period

	var prompt_builder = preload("res://scripts/prompt/PromptBuilder.gd").new()
	var prompt_payload = {
		"language": language,
		"subject": char_name,
		"description": case_desc,
		"year": world_year,
		"institution": institution,
		"document_type": dtype
	}
	var prompt_result = prompt_builder.build_generation_prompt("document", prompt_payload)
	var full_prompt = prompt_result.get("full_prompt", "")

	if gd_llama:
		gd_llama.context_size = 7000
		gd_llama.n_predict = 400
		gd_llama.temperature = 0.0 # Lower temperature for structural stability
		gd_llama.top_p = 0.9
		gd_llama.top_k = 40
		gd_llama.run_generate_text(full_prompt, "", "")
	else:
		_on_generation_finished("Official administrative record entry on file.")

func _on_generation_finished(generated_text: String) -> void:
	var raw_text = generated_text.strip_edges() if generated_text else ""
	raw_text = _sanitize_generated_text(raw_text)
	
	if "failed to initialize sampling subsystem" in raw_text or "unable to load model" in raw_text:
		raw_text = ""

	var drift_keywords = ["Humanism", "philosophy", "Humanists", "dignity", "Output:", "Context Facts:", "Here is", "Sure,", "As an AI"]
	for keyword in drift_keywords:
		var idx = raw_text.find(keyword)
		if idx != -1:
			raw_text = raw_text.substr(0, idx).strip_edges()

	var requester_data = _pending_case_data.get("requester", {})
	var char_name = "Local Resident"
	if typeof(requester_data) == TYPE_DICTIONARY:
		char_name = requester_data.get("name", requester_data.get("character_name", _pending_case_data.get("character_name", "Local Resident")))
	elif typeof(requester_data) == TYPE_STRING and not requester_data.is_empty():
		char_name = requester_data

	var world_context = _load_world_prompt_context()
	var world_year = int(world_context.get("year", 1942))
	var institution = str(world_context.get("institution", "District Archives Office"))

	if raw_text.is_empty() or raw_text.length() < 10:
		if world_year >= 1942 and world_year <= 1945:
			raw_text = "Kantor Arsip Daerah telah memverifikasi catatan resmi mengenai " + char_name + "."
		elif world_year < 1942:
			raw_text = "Het districtsarchief heeft het officiële document met betrekking tot " + char_name + " gecontroleerd."
		else:
			raw_text = "Catatan arsip resmi mengenai " + char_name + " telah diverifikasi."

	if _pending_doc_types.is_empty() or _current_doc_index >= _pending_doc_types.size():
		_finalize_documents()
		return

	var dtype = _pending_doc_types[_current_doc_index]
	var resolution = _pending_case_data.get("resolution", {})
	var correct_decision = resolution.get("correct_decision", "approve")

	var doc_language = "Bahasa Indonesia"
	if world_year >= 1942 and world_year <= 1945:
		doc_language = "Japanese Romaji"
	elif world_year < 1942:
		doc_language = "dutch"

	var doc_entry = _load_document_template(dtype)
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var assigned_score = 0
	if rng.randf() > 0.7:
		assigned_score = rng.randi_range(100, 200)
	else:
		assigned_score = 0

	var is_document_true = (correct_decision == "approve")

	if doc_entry.has("fields") and typeof(doc_entry["fields"]) == TYPE_DICTIONARY:
		_deep_populate_fields(doc_entry["fields"], char_name, raw_text, world_year, institution, doc_language, assigned_score, is_document_true)

	var safe_char_name = char_name.strip_edges().replace(" ", "_")
	var file_name = "%s_%s" % [dtype, safe_char_name]

	var case_id = _pending_case_data.get("id", "case-x").to_lower()
	var folder_path = "res://data/storage/document_pool/%s/" % case_id
	
	var dir = DirAccess.open("res://")
	if dir != null:
		if not dir.dir_exists(folder_path):
			dir.make_dir_recursive(folder_path)

	var file_path = folder_path + "%s.json" % file_name
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(doc_entry, "\t"))
		file.close()
		print("DocumentGeneration: Saved language-validated document -> %s" % file_path)

	_generated_docs.append({ "file_name": file_name, "document": doc_entry })
	_current_doc_index += 1
	_process_next_document()

func _load_world_prompt_context() -> Dictionary:
	var context = {
		"year": 1942,
		"institution": "District Archives Office"
	}

	var overview = _load_json_file(WORLD_OVERVIEW_FILE_PATH)
	if typeof(overview) == TYPE_DICTIONARY:
		var time_period = overview.get("time_period", {})
		if typeof(time_period) == TYPE_DICTIONARY:
			var start_year = time_period.get("start_year", 1940)
			var end_year = time_period.get("end_year", 1949)
			var resolved_year = 1942
			if typeof(start_year) == TYPE_INT:
				resolved_year = start_year
			elif typeof(start_year) == TYPE_STRING:
				resolved_year = start_year.to_int()
			if typeof(end_year) == TYPE_INT:
				if resolved_year < 1942 and end_year >= 1942:
					resolved_year = 1942
			elif typeof(end_year) == TYPE_STRING:
				var end_bound = end_year.to_int()
				if resolved_year < 1942 and end_bound >= 1942:
					resolved_year = 1942
			if resolved_year <= 0:
				resolved_year = 1942
			context["year"] = resolved_year
	
	var institution_data = _load_json_file(WORLD_INSTITUTIONS_FILE_PATH)
	if typeof(institution_data) == TYPE_ARRAY and not institution_data.is_empty():
		var first = institution_data[0]
		if typeof(first) == TYPE_DICTIONARY:
			var inst_name = first.get("name", "")
			if typeof(inst_name) == TYPE_STRING and not inst_name.is_empty():
				context["institution"] = inst_name

	return context

func _load_document_template(document_type: String) -> Dictionary:
	var safe_type = str(document_type).strip_edges()
	if safe_type.is_empty():
		safe_type = "official_notice"

	var template_path = TEMPLATE_DIR + "%s.json" % safe_type
	var doc_entry = _load_json_file(template_path)
	if typeof(doc_entry) != TYPE_DICTIONARY:
		print("DocumentGeneration: Missing template for %s; using schema fallback." % safe_type)
		doc_entry = {
			"type": safe_type,
			"fields": {}
		}
	else:
		if not doc_entry.has("type"):
			doc_entry["type"] = safe_type
		if typeof(doc_entry.get("type")) != TYPE_STRING:
			doc_entry["type"] = safe_type
		if not doc_entry.has("fields") or typeof(doc_entry.get("fields")) != TYPE_DICTIONARY:
			doc_entry["fields"] = {}
		if doc_entry.get("type", "") != safe_type:
			doc_entry["type"] = safe_type
	return doc_entry

func _deep_populate_fields(fields: Dictionary, char_name: String, narrative: String, year: int, issuer_name: String, lang: String, score: int, truth_flag: bool) -> void:
	for key in fields.keys():
		var val = fields[key]
		
		if key == "investigation_score":
			fields[key] = score
		elif key == "is_true":
			fields[key] = truth_flag
		elif key == "title" and (typeof(val) == TYPE_STRING and (val.is_empty() or val.begins_with("Official"))):
			fields[key] = "Official Record - " + char_name
		elif key in ["date", "effective_date"] and (typeof(val) == TYPE_STRING and val.is_empty()):
			fields[key] = "%d-06-12" % year
		elif key == "language" and (typeof(val) == TYPE_STRING and val.is_empty()):
			fields[key] = lang
		elif key == "issuer" and (typeof(val) == TYPE_STRING and val.is_empty()):
			fields[key] = issuer_name
		
		elif key in ["summary", "content", "statement", "remarks", "purpose", "description", "result", "notes", "reason", "text", "follow_up", "status", "condition", "treatment", "mood"] and (typeof(val) == TYPE_STRING and (val.is_empty() or val == "Verified on file" or val == "Verified")):
			fields[key] = narrative
			
		elif typeof(val) == TYPE_STRING and (val.is_empty() or val == "Verified on file" or val == "Verified"):
			if key == "fact":
				fields[key] = "Verified historical entry confirmed for " + char_name
			elif key == "importance":
				fields[key] = "Standard Verification"
			elif key == "record_type":
				fields[key] = "Archival Log"
			elif key == "event":
				fields[key] = "Official administrative review"
			elif key in ["text", "remarks", "summary", "content", "statement", "purpose", "description", "result", "notes", "reason", "follow_up", "status", "condition", "treatment", "mood"]:
				fields[key] = narrative
			else:
				fields[key] = "Verified on file"
			
		elif typeof(val) == TYPE_DICTIONARY:
			_deep_populate_fields(val, char_name, narrative, year, issuer_name, lang, score, truth_flag)
			
			for sub_key in val.keys():
				if sub_key in ["full_name", "name", "taxpayer", "employee", "author", "subject", "owner", "registered_owner", "patient", "husband", "wife", "recipient", "party_a", "party_b"] and (typeof(val[sub_key]) == TYPE_STRING and (val[sub_key].is_empty() or val[sub_key] == "Verified on file" or val[sub_key] == "Verified")):
					val[sub_key] = char_name
				elif sub_key in ["report_number", "record_number", "notice_number", "certificate_number", "verification_number"] and (typeof(val[sub_key]) == TYPE_STRING and (val[sub_key].is_empty() or val[sub_key] == "Verified on file" or val[sub_key] == "Verified")):
					val[sub_key] = "ARC-%d-%d" % [year, randi() % 900 + 100]
				elif sub_key in ["location", "work_location", "archive_location"] and (typeof(val[sub_key]) == TYPE_STRING and (val[sub_key].is_empty() or val[sub_key] == "Verified on file" or val[sub_key] == "Verified")):
					val[sub_key] = "District Archives Center, Sector " + str(randi() % 5 + 1)
				elif sub_key in ["text", "follow_up", "status", "condition", "treatment", "mood", "remarks", "summary", "content", "statement", "purpose", "description", "result", "notes", "reason"] and (typeof(val[sub_key]) == TYPE_STRING and (val[sub_key].is_empty() or val[sub_key] == "Verified on file" or val[sub_key] == "Verified")):
					val[sub_key] = narrative
				elif typeof(val[sub_key]) == TYPE_STRING and (val[sub_key].is_empty() or val[sub_key] == "Verified on file" or val[sub_key] == "Verified"):
					val[sub_key] = "Verified"

		elif typeof(val) == TYPE_ARRAY:
			for i in range(val.size()):
				var item = val[i]
				if typeof(item) == TYPE_DICTIONARY:
					_deep_populate_fields(item, char_name, narrative, year, issuer_name, lang, score, truth_flag)
				elif typeof(item) == TYPE_STRING and item.is_empty():
					if key == "findings":
						val[i] = "Verified archival entry regarding " + char_name
					elif key == "recommendations":
						val[i] = "Standard archival cross-reference complete."
					elif key == "related_documents":
						val[i] = "ARC-%d-REF" % year
					else:
						val[i] = narrative

func _finalize_documents() -> void:
	_is_busy = false
	var case_id = _pending_case_data.get("id", "case-x").to_lower()
	print("DocumentGeneration: Successfully generated and saved all %d documents for %s." % [_generated_docs.size(), case_id])
	documents_ready.emit(_generated_docs)

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

	var prompt_markers = [
		"instruction 2",
		"follow-up question",
		"what were some",
		"here is",
		"sure,",
		"as an ai",
		"generated text:"
	]
	for marker in prompt_markers:
		var idx = lower.find(marker)
		if idx != -1:
			cleaned = cleaned.substr(0, idx).strip_edges()
			lower = cleaned.to_lower()
			break

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

func _load_json_file(path: String):
	if FileAccess.file_exists(path):
		var f = FileAccess.open(path, FileAccess.READ)
		if f != null:
			var res = JSON.parse_string(f.get_as_text())
			f.close()
			return res
	return null
