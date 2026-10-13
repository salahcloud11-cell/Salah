extends Node





const SAVE_PATH: = "user://settings.cfg"

const MASTER_BUS: = "Master"
const MUSIC_BUS: = "Music"
const SFX_BUS: = "SFX"


const DEFAULT_MASTER_VOLUME: = 1.0
const DEFAULT_MUSIC_VOLUME: = 0.8
const DEFAULT_SFX_VOLUME: = 0.8
const DEFAULT_MOUSE_SENSITIVITY: = 0.004
const DEFAULT_FULLSCREEN: = true


const SENSITIVITY_MIN: = 0.001
const SENSITIVITY_MAX: = 0.02

var master_volume: float = DEFAULT_MASTER_VOLUME
var music_volume: float = DEFAULT_MUSIC_VOLUME
var sfx_volume: float = DEFAULT_SFX_VOLUME
var mouse_sensitivity: float = DEFAULT_MOUSE_SENSITIVITY
var fullscreen: bool = DEFAULT_FULLSCREEN


func _ready() -> void :
	_ensure_buses()
	_load()
	apply()




func _ensure_buses() -> void :
	_add_bus_if_missing(MUSIC_BUS)
	_add_bus_if_missing(SFX_BUS)


func _add_bus_if_missing(bus_name: String) -> void :
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	var idx: = AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, MASTER_BUS)



func apply() -> void :
	_set_bus_volume(MASTER_BUS, master_volume)
	_set_bus_volume(MUSIC_BUS, music_volume)
	_set_bus_volume(SFX_BUS, sfx_volume)
	apply_fullscreen()


func apply_fullscreen() -> void :
	var window: = get_window()
	if fullscreen:
		window.mode = Window.MODE_FULLSCREEN
	else:
		window.mode = Window.MODE_WINDOWED
		window.borderless = false


func _set_bus_volume(bus_name: String, volume: float) -> void :
	var idx: = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	var muted: = volume <= 0.001
	AudioServer.set_bus_mute(idx, muted)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(volume, 0.001)))




func set_master_volume(value: float) -> void :
	master_volume = clampf(value, 0.0, 1.0)
	_set_bus_volume(MASTER_BUS, master_volume)
	save()


func set_music_volume(value: float) -> void :
	music_volume = clampf(value, 0.0, 1.0)
	_set_bus_volume(MUSIC_BUS, music_volume)
	save()


func set_sfx_volume(value: float) -> void :
	sfx_volume = clampf(value, 0.0, 1.0)
	_set_bus_volume(SFX_BUS, sfx_volume)
	save()


func set_mouse_sensitivity(value: float) -> void :
	mouse_sensitivity = clampf(value, SENSITIVITY_MIN, SENSITIVITY_MAX)
	save()


func set_fullscreen(value: bool) -> void :
	fullscreen = value
	apply_fullscreen()
	save()




func _load() -> void :
	var config: = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	master_volume = config.get_value("audio", "master_volume", DEFAULT_MASTER_VOLUME)
	music_volume = config.get_value("audio", "music_volume", DEFAULT_MUSIC_VOLUME)
	sfx_volume = config.get_value("audio", "sfx_volume", DEFAULT_SFX_VOLUME)
	mouse_sensitivity = config.get_value("controls", "mouse_sensitivity", DEFAULT_MOUSE_SENSITIVITY)
	fullscreen = config.get_value("display", "fullscreen", DEFAULT_FULLSCREEN)


func save() -> void :
	var config: = ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("display", "fullscreen", fullscreen)
	config.save(SAVE_PATH)
