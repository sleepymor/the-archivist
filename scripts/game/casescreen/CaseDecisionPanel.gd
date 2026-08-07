extends Control
class_name CaseDecisionPanel

@export var case_inventory: CaseInventory
@export var case_pool_compiler: CasePoolCompiler

@export var accept_button: Button
@export var reject_button: Button
@export var investigate_button: Button

@export var result_popup: DecisionResultPopup
@export var info_popup: InfoPopup
@export var day_manager: DayManager
@export var trust_manager: TrustManager

const DEADLINE_PENALTY: float = 10.0

const INVESTIGATION_RANGES := {
	TrustManager.TrustSegment.LOW: Vector2(50, 75),
	TrustManager.TrustSegment.BASE: Vector2(75, 150),
	TrustManager.TrustSegment.HIGH: Vector2(100, 175),
}

func _ready() -> void:
	accept_button.pressed.connect(_on_accept_pressed)
	reject_button.pressed.connect(_on_reject_pressed)
	investigate_button.pressed.connect(_on_investigate_pressed)
	case_inventory.case_expired.connect(_on_case_expired)

func _on_case_expired(case_id: String) -> void:
	trust_manager.apply_penalty(DEADLINE_PENALTY)
	info_popup.show_message("Case %s expired! Trust -%s" % [case_id, DEADLINE_PENALTY])

func _on_accept_pressed() -> void:
	_resolve_case("approve")

func _on_reject_pressed() -> void:
	_resolve_case("reject")

func _on_investigate_pressed() -> void:
	var active: Dictionary = case_inventory.get_current_active_case()
	if active.is_empty():
		return

	var segment: TrustManager.TrustSegment = trust_manager.get_trust_segment()
	var range_value: Vector2 = INVESTIGATION_RANGES[segment]
	var gained: int = randi_range(int(range_value.x), int(range_value.y))

	var points: int = case_inventory.add_investigation_point(active["id"], gained)

	case_inventory.advance_day()
	day_manager.advance_day()

	info_popup.show_message("Investigation +%d. Total: %d" % [gained, points])

func _resolve_case(decision: String) -> void:
	var active: Dictionary = case_inventory.get_current_active_case()
	if active.is_empty():
		return

	var case_data: Dictionary = _find_case_data(active["id"])
	if case_data.is_empty():
		return

	var resolution: Dictionary = case_data["resolution"]
	var correct_decision: String = resolution["correct_decision"]
	var is_correct: bool = decision == correct_decision

	if is_correct:
		_on_correct_decision(case_data)
	else:
		_on_wrong_decision(case_data, decision)

	result_popup.show_result(is_correct, resolution["explanation"])

	case_inventory.remove_case(active["id"])
	case_inventory.advance_day()
	day_manager.advance_day()

func _on_correct_decision(case_data: Dictionary) -> void:
	print("Correct decision for ", case_data["id"])

func _on_wrong_decision(case_data: Dictionary, chosen: String) -> void:
	print("Wrong decision for ", case_data["id"], " chose: ", chosen, " correct: ", case_data["resolution"]["correct_decision"])
	trust_manager.apply_penalty()

func _find_case_data(id: String) -> Dictionary:
	for c in case_pool_compiler.pool:
		if c["id"] == id:
			return c
	return {}
