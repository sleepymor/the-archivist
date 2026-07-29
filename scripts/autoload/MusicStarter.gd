extends Node
@export var level_music: AudioStream

func _ready() -> void:
	call_deferred("_play_level_music")

func _play_level_music() -> void:
	if level_music and has_node("/root/MusicPlayer"):
		MusicPlayer.play_music(level_music, -5.0)
