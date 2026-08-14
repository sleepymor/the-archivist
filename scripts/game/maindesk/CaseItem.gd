extends BaseButton
class_name CaseItem

@export var id_label: Label
@export var deadline_label: Label
@export var case_inventory: CaseInventory
@export var switcher: ObjectSwitcher
@export var click_sound: AudioStream

var case_id: String = ""
var tween: Tween
var audio_player: AudioStreamPlayer


func setup(data: Dictionary) -> void:
	case_id = data["id"]

	if id_label:
		id_label.text = data["id"]

	refresh_deadline(data["deadline"])


func refresh_deadline(value: float) -> void:
	if deadline_label:
		deadline_label.text = "Deadline: %s" % str(value)


func _ready() -> void:
	pressed.connect(_on_pressed)

	mouse_entered.connect(_on_hover)
	mouse_exited.connect(_on_exit)
	button_down.connect(_on_press)
	button_up.connect(_on_release)

	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	audio_player.stream = click_sound


func _on_pressed() -> void:
	if click_sound:
		audio_player.play()

	case_inventory.set_current_active_case(case_id)
	switcher.switch_to(ObjectSwitcher.ObjectType.CASE)


func animate_scale(target: float, duration: float, trans := Tween.TRANS_QUAD) -> void:
	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_trans(trans)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE * target, duration)


func _on_hover() -> void:
	animate_scale(1.05, 0.08)


func _on_exit() -> void:
	animate_scale(1.0, 0.08)


func _on_press() -> void:
	animate_scale(0.94, 0.04)


func _on_release() -> void:
	if is_hovered():
		animate_scale(1.05, 0.12, Tween.TRANS_BACK)
	else:
		animate_scale(1.0, 0.08)
