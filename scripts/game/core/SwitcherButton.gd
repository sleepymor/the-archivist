extends BaseButton

@export var switcher: Node
@export var target: ObjectSwitcher.ObjectType
@export var click_sound: AudioStream

var tween: Tween
var audio_player: AudioStreamPlayer


func _ready() -> void:
	mouse_entered.connect(_on_hover)
	mouse_exited.connect(_on_exit)
	button_down.connect(_on_press)
	button_up.connect(_on_release)
	pressed.connect(_on_pressed)

	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	audio_player.stream = click_sound


func animate_scale(target_scale: float, duration: float, trans := Tween.TRANS_QUAD) -> void:
	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_trans(trans)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE * target_scale, duration)


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


func _on_pressed() -> void:
	if switcher == null:
		push_error("Button: switcher belum di-assign")
		return

	if click_sound:
		audio_player.play()

	switcher.switch_to(target)
