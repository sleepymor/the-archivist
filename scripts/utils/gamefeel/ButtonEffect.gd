extends BaseButton

@export var click_sound: AudioStream

var tween: Tween
var audio_player: AudioStreamPlayer


func _ready():
	mouse_entered.connect(_on_hover)
	mouse_exited.connect(_on_exit)
	button_down.connect(_on_press)
	button_up.connect(_on_release)
	pressed.connect(_on_pressed)

	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	audio_player.stream = click_sound


func _on_pressed():
	if click_sound:
		audio_player.play()


func animate_scale(target: float, duration: float, trans := Tween.TRANS_QUAD):
	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_trans(trans)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE * target, duration)


func _on_hover():
	animate_scale(1.05, 0.08)


func _on_exit():
	animate_scale(1.0, 0.08)


func _on_press():
	animate_scale(0.94, 0.04)


func _on_release():
	if is_hovered():
		animate_scale(1.05, 0.12, Tween.TRANS_BACK)
	else:
		animate_scale(1.0, 0.08)
