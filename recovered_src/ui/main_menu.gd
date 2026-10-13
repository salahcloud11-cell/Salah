extends Control




const GAME_SCENE: = "res://apartment/ApartmentBlockout.tscn"

const TITLE_TEXT: = "مستيقظ أم لا؟"

var _busy: bool = false
var _base_texts: Dictionary = {}


@onready var menu_wrap: CenterContainer = $MenuWrap
@onready var menu_container: VBoxContainer = $MenuWrap / MenuContainer
@onready var title_label: Label = $MenuWrap / MenuContainer / TitleLabel
@onready var start_button: Button = $MenuWrap / MenuContainer / StartButton
@onready var settings_button: Button = $MenuWrap / MenuContainer / SettingsButton
@onready var credits_button: Button = $MenuWrap / MenuContainer / CreditsButton
@onready var quit_button: Button = $MenuWrap / MenuContainer / QuitButton

@onready var settings_wrap: CenterContainer = $SettingsWrap
@onready var settings_panel: VBoxContainer = $SettingsWrap / SettingsPanel
@onready var master_slider: HSlider = $SettingsWrap / SettingsPanel / MasterRow / MasterSlider
@onready var master_value: Label = $SettingsWrap / SettingsPanel / MasterRow / MasterValue
@onready var music_slider: HSlider = $SettingsWrap / SettingsPanel / MusicRow / MusicSlider
@onready var music_value: Label = $SettingsWrap / SettingsPanel / MusicRow / MusicValue
@onready var sfx_slider: HSlider = $SettingsWrap / SettingsPanel / SfxRow / SfxSlider
@onready var sfx_value: Label = $SettingsWrap / SettingsPanel / SfxRow / SfxValue
@onready var sens_slider: HSlider = $SettingsWrap / SettingsPanel / SensRow / SensSlider
@onready var sens_value: Label = $SettingsWrap / SettingsPanel / SensRow / SensValue
@onready var fullscreen_button: Button = $SettingsWrap / SettingsPanel / FullscreenRow / FullscreenButton
@onready var back_button: Button = $SettingsWrap / SettingsPanel / BackButton

@onready var credits_wrap: CenterContainer = $CreditsWrap
@onready var credits_back_button: Button = $CreditsWrap / CreditsPanel / CreditsBackButton

@onready var fade: ColorRect = $Fade
@onready var hover_sfx: AudioStreamPlayer = $Audio / HoverSFX
@onready var click_sfx: AudioStreamPlayer = $Audio / ClickSFX
@onready var start_sfx: AudioStreamPlayer = $Audio / StartSFX

var _menu_buttons: Array[Button] = []


func _ready() -> void :
	title_label.text = TITLE_TEXT
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_menu_buttons = [start_button, settings_button, credits_button, quit_button]
	for button in _menu_buttons:
		_base_texts[button] = button.text
		button.mouse_entered.connect(_on_hover)
		button.focus_entered.connect(_refresh_menu_arrows)
		button.pressed.connect(_on_button_pressed.bind(button))

	credits_back_button.pressed.connect(_close_credits)

	_build_sfx()

	fullscreen_button.pressed.connect(_on_fullscreen_pressed)
	back_button.pressed.connect(_on_back_pressed)

	_refresh_menu_arrows()
	_refresh_fullscreen_button()

	master_slider.value = Settings.master_volume
	music_slider.value = Settings.music_volume
	sfx_slider.value = Settings.sfx_volume
	sens_slider.min_value = Settings.SENSITIVITY_MIN
	sens_slider.max_value = Settings.SENSITIVITY_MAX
	sens_slider.step = 0.0005
	sens_slider.value = Settings.mouse_sensitivity

	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	sens_slider.value_changed.connect(_on_sens_changed)

	_update_slider_labels()
	settings_wrap.visible = false
	start_button.grab_focus()


	fade.color.a = 1.0
	var tw: = create_tween()
	tw.tween_property(fade, "color:a", 0.0, 0.7)


func _build_sfx() -> void :
	hover_sfx.bus = Settings.SFX_BUS
	click_sfx.bus = Settings.SFX_BUS
	start_sfx.bus = Settings.SFX_BUS
	hover_sfx.stream = _make_tone(950.0, 0.045, 0.1, 45.0)
	click_sfx.stream = _make_tone(280.0, 0.09, 0.28, 26.0)
	start_sfx.stream = _make_tone(200.0, 0.38, 0.3, 9.0)


func _make_tone(freq: float, duration: float, amp: float, decay: float) -> AudioStreamWAV:
	var mix_rate: = 22050
	var sample_count: = int(duration * mix_rate)
	var data: = PackedByteArray()
	data.resize(sample_count * 2)
	for i in sample_count:
		var t: = float(i) / mix_rate
		var s: = sin(TAU * freq * t) * exp( - decay * t) * amp
		var v: = int(clampf(s, -1.0, 1.0) * 32767.0)
		data[i * 2] = v & 255
		data[i * 2 + 1] = (v >> 8) & 255
	var wav: = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.data = data
	return wav


func _on_hover() -> void :
	if not _busy:
		hover_sfx.play()


func _on_button_pressed(button: Button) -> void :
	if _busy:
		return
	if button == start_button:
		_start_game()
	elif button == settings_button:
		click_sfx.play()
		_open_settings()
	elif button == credits_button:
		click_sfx.play()
		_open_credits()
	elif button == quit_button:
		click_sfx.play()
		get_tree().quit()


func _start_game() -> void :
	_busy = true
	start_sfx.play()
	for button in _menu_buttons:
		button.focus_mode = Control.FOCUS_NONE
	await _fade_to_black()
	get_tree().change_scene_to_file(GAME_SCENE)


func _fade_to_black() -> void :
	fade.color.a = 0.0
	var tw: = create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.4)
	await tw.finished


func _open_settings() -> void :
	menu_wrap.visible = false
	settings_wrap.visible = true
	back_button.grab_focus()


func _close_settings() -> void :
	settings_wrap.visible = false
	menu_wrap.visible = true
	start_button.grab_focus()


func _open_credits() -> void :
	menu_wrap.visible = false
	credits_wrap.visible = true
	credits_back_button.grab_focus()


func _close_credits() -> void :
	click_sfx.play()
	credits_wrap.visible = false
	menu_wrap.visible = true
	start_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void :
	if _busy:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if settings_wrap.visible:
			_close_settings()
			get_viewport().set_input_as_handled()
		elif credits_wrap.visible:
			_close_credits()
			get_viewport().set_input_as_handled()


func _refresh_menu_arrows() -> void :
	for button in _menu_buttons:
		var focused: = button.has_focus()
		button.text = ("> " if focused else "   ") + _base_texts[button]


func _on_master_changed(v: float) -> void :
	Settings.set_master_volume(v)
	master_value.text = _pct(v)


func _on_music_changed(v: float) -> void :
	Settings.set_music_volume(v)
	music_value.text = _pct(v)


func _on_sfx_changed(v: float) -> void :
	Settings.set_sfx_volume(v)
	sfx_value.text = _pct(v)


func _on_sens_changed(v: float) -> void :
	Settings.set_mouse_sensitivity(v)
	sens_value.text = "%.3f" % v


func _update_slider_labels() -> void :
	master_value.text = _pct(master_slider.value)
	music_value.text = _pct(music_slider.value)
	sfx_value.text = _pct(sfx_slider.value)
	sens_value.text = "%.3f" % sens_slider.value


func _refresh_fullscreen_button() -> void :
	fullscreen_button.text = "ملء الشاشة   [ %s ]" % ("تشغيل" if Settings.fullscreen else "إيقاف")


func _on_fullscreen_pressed() -> void :
	click_sfx.play()
	Settings.set_fullscreen( not Settings.fullscreen)
	_refresh_fullscreen_button()


func _on_back_pressed() -> void :
	click_sfx.play()
	_close_settings()


func _pct(v: float) -> String:
	return "%d%%" % roundi(v * 100.0)
