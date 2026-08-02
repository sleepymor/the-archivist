extends Node

signal documents_ready(documents_data: Array)

const TEMPLATE_DIR = "res://data/templates/document_template/"
const WORLD_FILE_PATH = "res://data/static/world.json"

@onready var gd_llama = $"../GDLlama"

var _is_busy: bool = false
var _pending_case_data: Dictionary = {}
var _pending_doc_types: Array = []
var _generated_docs: Array = []
var _current_doc_index: int = 0

func _ready() -> void:
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

	var world_data = _load_json_file(WORLD_FILE_PATH)
	var world_year = 1942
	if typeof(world_data) == TYPE_DICTIONARY:
		world_year = world_data.get("year", world_data.get("current_year", 1942))

	var system_prompt = ""
	var prompt = ""
	
	if world_year >= 1942 and world_year <= 1945:
		system_prompt = "You are a strict historical archivist. Output text ONLY in Japanese Romaji using the Latin alphabet (A-Z). Return only the report sentence, with no English words, no explanation, and no introductory text."
		prompt = "Write a short official summary report for subject: %s. Details: %s. Romaji text only. Return only the report." % [char_name, case_desc]
	elif world_year < 1942:
		system_prompt = "Je bent een historische archivaris. Schrijf uitsluitend in het Nederlands. Gebruik geen Engels en geef alleen de samenvatting terug."
		prompt = "Schrijf een kort officieel samenvattingsrapport voor onderwerp: %s. Details: %s. Nederlandse tekst alleen." % [char_name, case_desc]
	else:
		system_prompt = "Anda adalah arsiparis sejarah. Tulis hanya dalam Bahasa Indonesia. Jangan gunakan Bahasa Inggris dan kembalikan hanya ringkasannya."
		prompt = "Tulis ringkasan laporan resmi singkat untuk subjek: %s. Detail: %s. Hanya teks Bahasa Indonesia." % [char_name, case_desc]
	var full_prompt = "%s\n\n%s" % [system_prompt, prompt]

	if gd_llama:
		gd_llama.context_size = 1024 # Constrain memory usage to prevent OOM
		gd_llama.n_predict = 250
		gd_llama.temperature = 0.1
		gd_llama.top_p = 0.9
		gd_llama.top_k = 40
		gd_llama.run_generate_text(full_prompt, "", "")
	else:
		_on_generation_finished("Official administrative record entry on file regarding verified investigation.")

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

	var world_data = _load_json_file(WORLD_FILE_PATH)
	var world_year = 1942
	var institution = "District Archives Office"
	if typeof(world_data) == TYPE_DICTIONARY:
		world_year = world_data.get("year", world_data.get("current_year", 1942))
		institution = world_data.get("institution", world_data.get("archive_issuer", "District Archives Office"))

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
		doc_language = "Nederlands"

	var template_path = TEMPLATE_DIR + "%s.json" % dtype
	var doc_entry = _load_json_file(template_path)
	if typeof(doc_entry) != TYPE_DICTIONARY:
		doc_entry = { "type": dtype, "fields": {} }

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
