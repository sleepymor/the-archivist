extends BaseButton

@export var case_pool_compiler: CasePoolCompiler
@export var case_inventory: CaseInventory
@export var case_spawn_manager: CaseSpawnManager
@export var click_sound: AudioStream

var tween: Tween
var audio_player: AudioStreamPlayer


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
	if case_inventory == null or case_pool_compiler == null or case_spawn_manager == null:
		push_error("AcceptCaseButton: export tidak di-assign")
		return

	var current: Dictionary = case_pool_compiler.current_case

	if current.is_empty():
		return

	if click_sound:
		audio_player.play()

	case_inventory.add_case(current)
	case_pool_compiler.clear_display()
	case_spawn_manager._set_objects_visible(false)


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
