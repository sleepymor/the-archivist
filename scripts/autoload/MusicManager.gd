extends Node

var bgm_player: AudioStreamPlayer

func _ready() -> void:
	bgm_player = AudioStreamPlayer.new()
	add_child(bgm_player)
	
	bgm_player.bus = "Master" 
	bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS 
	
func play_music(stream: AudioStream, volume: float = 0.0):
	if bgm_player.stream == stream and bgm_player.playing:
		return
		
	bgm_player.stream = stream
	bgm_player.volume_db = volume
	bgm_player.play()

func stop_music():
	bgm_player.stop()
