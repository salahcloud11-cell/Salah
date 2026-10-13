extends Node





const MUSIC_PATH: = "res://audio/menu_music.ogg"

var _player: AudioStreamPlayer


func _ready() -> void :
	_player = AudioStreamPlayer.new()
	_player.name = "MusicPlayer"
	_player.bus = Settings.MUSIC_BUS
	_player.stream = load(MUSIC_PATH)
	if _player.stream is AudioStreamOggVorbis:
		(_player.stream as AudioStreamOggVorbis).loop = true
	_player.finished.connect(_on_finished)
	add_child(_player)
	_player.play()


func _on_finished() -> void :
	if not _player.playing:
		_player.play()



func stop_music() -> void :
	if _player:
		_player.stop()



func play_music() -> void :
	if _player and not _player.playing:
		_player.play()
