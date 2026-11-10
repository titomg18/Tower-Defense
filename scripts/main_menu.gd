extends Control

const SAVE_PATH := "user://save_data.cfg"
const GAME_SCENE_PATH := "res://scenes/Main.tscn"

const SFX_CLICK := preload("res://assets/sounds/build_tower.wav")
const SFX_UPGRADE := preload("res://assets/sounds/upgrade_tower.wav")

var highest_wave: int = 0
var spent_points: int = 0
var bonus_coins_lv: int = 0
var bonus_lives_lv: int = 0
var bonus_damage_lv: int = 0
var _confirm_reset: bool = false

@onready var settings_button: Button = $SettingsButton
@onready var record_value_label: Label = $RecordBoard/Margin/VBox/RecordValueLabel

@onready var play_button: Button = $MenuButtons/PlayButton
@onready var shop_button: Button = $MenuButtons/ShopButton
@onready var help_button: Button = $MenuButtons/HelpButton
@onready var quit_button: Button = $MenuButtons/QuitButton

@onready var shop_modal: ColorRect = $ShopModal
@onready var points_label: Label = $ShopModal/Panel/Margin/VBox/Header/PointsLabel
@onready var close_shop_button: Button = $ShopModal/Panel/Margin/VBox/Header/CloseShopButton
@onready var perk_coins_button: Button = $ShopModal/Panel/Margin/VBox/PerkCoinsButton
@onready var perk_lives_button: Button = $ShopModal/Panel/Margin/VBox/PerkLivesButton
@onready var perk_damage_button: Button = $ShopModal/Panel/Margin/VBox/PerkDamageButton

@onready var help_modal: ColorRect = $HelpModal
@onready var close_help_button: Button = $HelpModal/Panel/Margin/VBox/Header/CloseHelpButton

@onready var settings_modal: ColorRect = $SettingsModal
@onready var close_settings_button: Button = $SettingsModal/Panel/Margin/VBox/Header/CloseSettingsButton
@onready var sound_toggle_button: Button = $SettingsModal/Panel/Margin/VBox/SoundToggleButton
@onready var volume_label: Label = $SettingsModal/Panel/Margin/VBox/VolumeLabel
@onready var volume_slider: HSlider = $SettingsModal/Panel/Margin/VBox/VolumeSlider
@onready var reset_save_button: Button = $SettingsModal/Panel/Margin/VBox/ResetSaveButton

@onready var bgm_player: AudioStreamPlayer = $BgmPlayer
@onready var ui_sfx_player: AudioStreamPlayer = $UiSfxPlayer


func _ready() -> void:
	_load_data()
	_apply_wooden_theme()

	play_button.pressed.connect(_on_play_pressed)
	shop_button.pressed.connect(_on_shop_pressed)
	help_button.pressed.connect(_on_help_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	settings_button.pressed.connect(_on_settings_pressed)

	close_shop_button.pressed.connect(func() -> void:
		_play_click()
		shop_modal.visible = false
	)
	close_help_button.pressed.connect(func() -> void:
		_play_click()
		help_modal.visible = false
	)
	close_settings_button.pressed.connect(func() -> void:
		_play_click()
		_confirm_reset = false
		reset_save_button.text = "Reset Data Rekor & Toko"
		settings_modal.visible = false
	)

	perk_coins_button.pressed.connect(_on_buy_perk_coins)
	perk_lives_button.pressed.connect(_on_buy_perk_lives)
	perk_damage_button.pressed.connect(_on_buy_perk_damage)

	sound_toggle_button.toggled.connect(_on_sound_toggled)
	volume_slider.value_changed.connect(_on_volume_changed)
	reset_save_button.pressed.connect(_on_reset_save_pressed)
	bgm_player.finished.connect(func() -> void:
		if bgm_player != null:
			bgm_player.play()
	)

	var is_muted: bool = AudioServer.is_bus_mute(0)
	sound_toggle_button.set_pressed_no_signal(not is_muted)
	sound_toggle_button.text = "Suara & Musik: ON" if not is_muted else "Suara & Musik: OFF"

	var current_db: float = AudioServer.get_bus_volume_db(0)
	var linear_pct: float = clampf(db_to_linear(current_db) * 100.0, 0.0, 100.0)
	volume_slider.set_value_no_signal(linear_pct)
	volume_label.text = "Volume Utama: %d%%" % int(round(linear_pct))

	shop_modal.visible = false
	help_modal.visible = false
	settings_modal.visible = false

	_refresh_menu_ui()


func _get_available_points() -> int:
	return maxi(0, highest_wave * 10 - spent_points)


func _refresh_menu_ui() -> void:
	record_value_label.text = "WAVE %d" % highest_wave
	var pts: int = _get_available_points()
	points_label.text = "Poin Rekor: %d" % pts

	if bonus_coins_lv < 4:
		perk_coins_button.text = "Koin Awal +25 (Lv.%d/4) — Biaya: 10 Poin" % bonus_coins_lv
		perk_coins_button.disabled = pts < 10
	else:
		perk_coins_button.text = "Koin Awal +100 (MAX)"
		perk_coins_button.disabled = true

	if bonus_lives_lv < 3:
		perk_lives_button.text = "Nyawa Awal +2 (Lv.%d/3) — Biaya: 10 Poin" % bonus_lives_lv
		perk_lives_button.disabled = pts < 10
	else:
		perk_lives_button.text = "Nyawa Awal +6 (MAX)"
		perk_lives_button.disabled = true

	if bonus_damage_lv < 3:
		perk_damage_button.text = "Damage Semua Tower +10%% (Lv.%d/3) — Biaya: 20 Poin" % bonus_damage_lv
		perk_damage_button.disabled = pts < 20
	else:
		perk_damage_button.text = "Damage Semua Tower +30%% (MAX)"
		perk_damage_button.disabled = true


func _on_play_pressed() -> void:
	_play_click()
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _on_shop_pressed() -> void:
	_play_click()
	_refresh_menu_ui()
	shop_modal.visible = true


func _on_help_pressed() -> void:
	_play_click()
	help_modal.visible = true


func _on_settings_pressed() -> void:
	_play_click()
	_confirm_reset = false
	reset_save_button.text = "Reset Data Rekor & Toko"
	settings_modal.visible = true


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_buy_perk_coins() -> void:
	if bonus_coins_lv >= 4 or _get_available_points() < 10:
		return
	spent_points += 10
	bonus_coins_lv += 1
	_save_data()
	_play_upgrade()
	_refresh_menu_ui()


func _on_buy_perk_lives() -> void:
	if bonus_lives_lv >= 3 or _get_available_points() < 10:
		return
	spent_points += 10
	bonus_lives_lv += 1
	_save_data()
	_play_upgrade()
	_refresh_menu_ui()


func _on_buy_perk_damage() -> void:
	if bonus_damage_lv >= 3 or _get_available_points() < 20:
		return
	spent_points += 20
	bonus_damage_lv += 1
	_save_data()
	_play_upgrade()
	_refresh_menu_ui()


func _on_sound_toggled(sound_on: bool) -> void:
	AudioServer.set_bus_mute(0, not sound_on)
	sound_toggle_button.text = "Suara & Musik: ON" if sound_on else "Suara & Musik: OFF"
	if sound_on:
		_play_click()


func _on_volume_changed(val: float) -> void:
	volume_label.text = "Volume Utama: %d%%" % int(round(val))
	if val <= 0.5:
		AudioServer.set_bus_volume_db(0, -80.0)
	else:
		AudioServer.set_bus_volume_db(0, linear_to_db(val / 100.0))


func _on_reset_save_pressed() -> void:
	if not _confirm_reset:
		_confirm_reset = true
		reset_save_button.text = "Klik Sekali Lagi untuk Konfirmasi Reset"
		_play_click()
		return

	_confirm_reset = false
	highest_wave = 0
	spent_points = 0
	bonus_coins_lv = 0
	bonus_lives_lv = 0
	bonus_damage_lv = 0
	_save_data()
	_play_click()
	reset_save_button.text = "Data Berhasil Direset!"
	_refresh_menu_ui()


func _play_click() -> void:
	if ui_sfx_player != null:
		ui_sfx_player.stream = SFX_CLICK
		ui_sfx_player.play()


func _play_upgrade() -> void:
	if ui_sfx_player != null:
		ui_sfx_player.stream = SFX_UPGRADE
		ui_sfx_player.play()


func _load_data() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		highest_wave = int(config.get_value("progress", "highest_wave", 0))
		spent_points = int(config.get_value("shop", "spent_points", 0))
		bonus_coins_lv = int(config.get_value("shop", "bonus_coins_lv", 0))
		bonus_lives_lv = int(config.get_value("shop", "bonus_lives_lv", 0))
		bonus_damage_lv = int(config.get_value("shop", "bonus_damage_lv", 0))


func _save_data() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "highest_wave", highest_wave)
	config.set_value("shop", "spent_points", spent_points)
	config.set_value("shop", "bonus_coins_lv", bonus_coins_lv)
	config.set_value("shop", "bonus_lives_lv", bonus_lives_lv)
	config.set_value("shop", "bonus_damage_lv", bonus_damage_lv)
	config.save(SAVE_PATH)


func _apply_wooden_theme() -> void:
	_style_wood_button(play_button, Color(0.46, 0.28, 0.13), Color(0.95, 0.76, 0.22), 5, 14)
	for btn in [shop_button, help_button, quit_button, settings_button]:
		_style_wood_button(btn, Color(0.47, 0.29, 0.15), Color(0.20, 0.11, 0.05), 4, 12)

	for panel in [
		$RecordBoard,
		$ShopModal/Panel,
		$HelpModal/Panel,
		$SettingsModal/Panel,
	]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.38, 0.23, 0.12, 0.97)
		sb.border_color = Color(0.18, 0.10, 0.04)
		sb.set_border_width_all(4)
		sb.set_corner_radius_all(12)
		sb.shadow_color = Color(0, 0, 0, 0.45)
		sb.shadow_size = 6
		panel.add_theme_stylebox_override("panel", sb)

	var ribbon_sb := StyleBoxFlat.new()
	ribbon_sb.bg_color = Color(0.76, 0.54, 0.30)
	ribbon_sb.border_color = Color(0.22, 0.13, 0.05)
	ribbon_sb.set_border_width_all(3)
	ribbon_sb.set_corner_radius_all(8)
	$TitleBox/RibbonCenter/RibbonPanel.add_theme_stylebox_override("panel", ribbon_sb)


func _style_wood_button(btn: Button, fill: Color, border: Color, border_w: int, radius: int) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = fill
	normal.border_color = border
	normal.set_border_width_all(border_w)
	normal.set_corner_radius_all(radius)
	normal.shadow_color = Color(0, 0, 0, 0.45)
	normal.shadow_size = 5
	normal.shadow_offset = Vector2(0, 3)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = fill.lightened(0.12)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = fill.darkened(0.12)
	pressed.shadow_offset = Vector2(0, 1)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
