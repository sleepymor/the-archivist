extends Button

@export_file("*.tscn") var target_scene_path: String

func _ready():
	pressed.connect(_on_pressed)

func _on_pressed():
	if target_scene_path != "":
		get_tree().change_scene_to_file(target_scene_path)
