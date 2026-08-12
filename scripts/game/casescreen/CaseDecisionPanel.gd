extends Control
class_name CaseDecisionPanel

@export var case_inventory: CaseInventory

@export var accept_button: TextureButton
@export var reject_button: TextureButton
@export var investigate_button: TextureButton

@export var result_popup: DecisionResultPopup
@export var info_popup: InfoPopup
@export var document_found_popup: DocumentFoundPopup
@export var day_manager: DayManager
@export var trust_manager: TrustManager
@export var document_spawn_manager: DocumentSpawnManager

const DEADLINE_PENALTY: float = 10.0

const INVESTIGATION_RANGES := {
	TrustManager.TrustSegment.LOW: Vector2(50, 75),
	TrustManager.TrustSegment.BASE: Vector2(75, 150),
	TrustManager.TrustSegment.HIGH: Vector2(100, 175),
}

var _pending_revealed_docs: Dictionary = {}

func _ready() -> void:
	accept_button.pressed.connect(_on_accept_pressed)
	reject_button.pressed.connect(_on_reject_pressed)
	investigate_button.pressed.connect(_on_investigate_pressed)
	case_inventory.case_expired.connect(_on_case_expired)

	info_popup.closed.connect(_on_info_popup_closed)
	result_popup.closed.connect(_on_result_popup_closed)

func _on_case_expired(case_id: String) -> void:
	trust_manager.apply_penalty(DEADLINE_PENALTY)
	info_popup.show_message("Case %s expired! Trust -%s" % [case_id, DEADLINE_PENALTY])

func _on_accept_pressed() -> void:
	_resolve_case("accept")

func _on_reject_pressed() -> void:
	_resolve_case("reject")

func _normalize_decision(decision: String) -> String:
	var normalized: String = decision.to_lower()
	if normalized == "approve":
		normalized = "accept"
	return normalized

func _on_investigate_pressed() -> void:
	var active: Dictionary = case_inventory.get_current_active_case()
	if active.is_empty():
		return

	var segment: TrustManager.TrustSegment = trust_manager.get_trust_segment()
	var range_value: Vector2 = INVESTIGATION_RANGES[segment]
	var gained: int = randi_range(int(range_value.x), int(range_value.y))

	var points: int = case_inventory.add_investigation_point(active["id"], gained)

	case_inventory.advance_day()
	_pending_revealed_docs = document_spawn_manager.process_day(active["id"])

	day_manager.advance_day()

	info_popup.show_message("Investigation +%d. Total: %d" % [gained, points])

func _resolve_case(decision: String) -> void:
	var active: Dictionary = case_inventory.get_current_active_case()
	if active.is_empty():
		return

	var case_data: Dictionary = active.get("data", {})
	if case_data.is_empty():
		return

	var resolution: Dictionary = case_data["resolution"]
	var correct_decision: String = _normalize_decision(resolution.get("correct_decision", ""))
	var chosen_decision: String = _normalize_decision(decision)
	var is_correct: bool = chosen_decision == correct_decision

	if is_correct:
		_on_correct_decision(case_data)
	else:
		_on_wrong_decision(case_data, decision)

	case_inventory.remove_case(active["id"])
	case_inventory.advance_day()
	_pending_revealed_docs = document_spawn_manager.process_day()

	day_manager.advance_day()

	result_popup.show_result(is_correct, resolution["explanation"])

func _on_correct_decision(case_data: Dictionary) -> void:
	print("Correct decision for ", case_data["id"])

func _on_wrong_decision(case_data: Dictionary, chosen: String) -> void:
	print("Wrong decision for ", case_data["id"], " chose: ", chosen, " correct: ", case_data["resolution"]["correct_decision"])
	trust_manager.apply_penalty()

func _on_info_popup_closed() -> void:
	document_found_popup.show_documents(_pending_revealed_docs)
	_pending_revealed_docs = {}

func _on_result_popup_closed() -> void:
	document_found_popup.show_documents(_pending_revealed_docs)
	_pending_revealed_docs = {}
