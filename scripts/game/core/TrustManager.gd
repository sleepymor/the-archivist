extends Node
class_name TrustManager

signal trust_changed(current: float, max: float)
signal trust_depleted

enum TrustSegment { LOW, BASE, HIGH }

@export var trust_bar: ProgressBar
@export var max_trust: float = 100.0
@export var penalty_amount: float = 10.0

var current_trust: float

func _ready() -> void:
	current_trust = max_trust
	_update_bar()

func apply_penalty(amount: float = -1.0) -> void:
	var value := amount if amount >= 0.0 else penalty_amount
	current_trust = clamp(current_trust - value, 0.0, max_trust)
	_update_bar()
	trust_changed.emit(current_trust, max_trust)

	if current_trust <= 0.0:
		trust_depleted.emit()

func get_trust_segment() -> TrustSegment:
	var ratio: float = current_trust / max_trust
	if ratio < 0.33:
		return TrustSegment.LOW
	elif ratio < 0.66:
		return TrustSegment.BASE
	else:
		return TrustSegment.HIGH

func _update_bar() -> void:
	if trust_bar:
		trust_bar.max_value = max_trust
		trust_bar.value = current_trust
