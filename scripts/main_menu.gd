extends Control

const SAVE_PATH := "user://save_data.cfg"
const GAME_SCENE_PATH := "res://scenes/Main.tscn"

const SFX_CLICK := preload("res://assets/sounds/build_tower.wav")
const SFX_UPGRADE := preload("res://assets/sounds/upgrade_tower.wav")

const ICON_COIN := preload("res://assets/images/icon_coin.png")
const ICON_GEM := preload("res://assets/images/icon_gem.png")

const DEFAULT_SHOP_COINS := 250
const DEFAULT_SHOP_GEMS := 50

const TOWER_ORDER := ["archer", "ice", "cannon", "tesla"]
const CATEGORY_ORDER := ["archer", "ice", "cannon", "tesla", "owned"]
const CATEGORY_LABELS := {
	"archer": "Archer Tower",
	"ice": "Ice Tower",
	"cannon": "Cannon Tower",
	"tesla": "Tesla Tower",
	"owned": "Dimiliki",
}

const TOWER_DEFAULT_TEXTURES := {
	"archer": preload("res://assets/images/archer_tower.png"),
	"ice": preload("res://assets/images/ice_tower.png"),
	"cannon": preload("res://assets/images/cannon_tower.png"),
	"tesla": preload("res://assets/images/tesla_tower.png"),
}

const SKIN_CATALOG := [
	# --- Archer Tower ---
	{
		"id": "archer_emas",
		"name": "Skin Emas",
		"tower_type": "archer",
		"currency": "coins",
		"price": 60,
		"name_color": Color(1.0, 0.88, 0.45),
		"texture": preload("res://assets/images/skin_archer_emas.png"),
	},
	{
		"id": "archer_elven",
		"name": "Skin Elven",
		"tower_type": "archer",
		"currency": "gems",
		"price": 20,
		"name_color": Color(0.62, 0.96, 0.56),
		"texture": preload("res://assets/images/skin_archer_elven.png"),
	},
	{
		"id": "archer_steampunk",
		"name": "Skin Steampunk",
		"tower_type": "archer",
		"currency": "coins",
		"price": 85,
		"name_color": Color(0.96, 0.76, 0.48),
		"texture": preload("res://assets/images/skin_archer_steampunk.png"),
	},
	{
		"id": "archer_es",
		"name": "Skin Es",
		"tower_type": "archer",
		"currency": "gems",
		"price": 30,
		"name_color": Color(0.68, 0.92, 1.0),
		"texture": preload("res://assets/images/skin_archer_es.png"),
	},
	# --- Ice Tower ---
	{
		"id": "ice_emas",
		"name": "Skin Emas",
		"tower_type": "ice",
		"currency": "coins",
		"price": 60,
		"name_color": Color(1.0, 0.88, 0.45),
		"texture": preload("res://assets/images/skin_ice_emas.png"),
	},
	{
		"id": "ice_elven",
		"name": "Skin Elven",
		"tower_type": "ice",
		"currency": "gems",
		"price": 20,
		"name_color": Color(0.62, 0.96, 0.56),
		"texture": preload("res://assets/images/skin_ice_elven.png"),
	},
	{
		"id": "ice_steampunk",
		"name": "Skin Steampunk",
		"tower_type": "ice",
		"currency": "coins",
		"price": 85,
		"name_color": Color(0.96, 0.76, 0.48),
		"texture": preload("res://assets/images/skin_ice_steampunk.png"),
	},
	{
		"id": "ice_api",
		"name": "Skin Api",
		"tower_type": "ice",
		"currency": "gems",
		"price": 35,
		"name_color": Color(1.0, 0.68, 0.42),
		"texture": preload("res://assets/images/skin_ice_api.png"),
	},
	# --- Cannon Tower ---
	{
		"id": "cannon_emas",
		"name": "Skin Emas",
		"tower_type": "cannon",
		"currency": "coins",
		"price": 60,
		"name_color": Color(1.0, 0.88, 0.45),
		"texture": preload("res://assets/images/skin_cannon_emas.png"),
	},
	{
		"id": "cannon_elven",
		"name": "Skin Elven",
		"tower_type": "cannon",
		"currency": "gems",
		"price": 20,
		"name_color": Color(0.62, 0.96, 0.56),
		"texture": preload("res://assets/images/skin_cannon_elven.png"),
	},
	{
		"id": "cannon_steampunk",
		"name": "Skin Steampunk",
		"tower_type": "cannon",
		"currency": "coins",
		"price": 85,
		"name_color": Color(0.96, 0.76, 0.48),
		"texture": preload("res://assets/images/skin_cannon_steampunk.png"),
	},
	{
		"id": "cannon_api",
		"name": "Skin Api",
		"tower_type": "cannon",
		"currency": "gems",
		"price": 35,
		"name_color": Color(1.0, 0.68, 0.42),
		"texture": preload("res://assets/images/skin_cannon_api.png"),
	},
	# --- Tesla Tower ---
	{
		"id": "tesla_emas",
		"name": "Skin Emas",
		"tower_type": "tesla",
		"currency": "coins",
		"price": 60,
		"name_color": Color(1.0, 0.88, 0.45),
		"texture": preload("res://assets/images/skin_tesla_emas.png"),
	},
	{
		"id": "tesla_elven",
		"name": "Skin Elven",
		"tower_type": "tesla",
		"currency": "gems",
		"price": 20,
		"name_color": Color(0.62, 0.96, 0.56),
		"texture": preload("res://assets/images/skin_tesla_elven.png"),
	},
	{
		"id": "tesla_steampunk",
		"name": "Skin Steampunk",
		"tower_type": "tesla",
		"currency": "coins",
		"price": 85,
		"name_color": Color(0.96, 0.76, 0.48),
		"texture": preload("res://assets/images/skin_tesla_steampunk.png"),
	},
	{
		"id": "tesla_api",
		"name": "Skin Api",
		"tower_type": "tesla",
		"currency": "gems",
		"price": 35,
		"name_color": Color(1.0, 0.68, 0.42),
		"texture": preload("res://assets/images/skin_tesla_api.png"),
	},
]

var highest_wave: int = 0
var shop_coins: int = DEFAULT_SHOP_COINS
var shop_gems: int = DEFAULT_SHOP_GEMS
var active_shop_category: String = "archer"
var owned_skins: Array[String] = []
var equipped_skins: Dictionary = {
	"archer": "",
	"ice": "",
	"cannon": "",
	"tesla": "",
}
var _skin_pack_v2_bonus: bool = true
var _confirm_reset: bool = false

@onready var archer_decor: TextureRect = $DecorLayer/ArcherDecor
@onready var cannon_decor: TextureRect = $DecorLayer/CannonDecor

@onready var settings_button: Button = $SettingsButton
@onready var record_value_label: Label = $RecordBoard/Margin/VBox/RecordValueLabel

@onready var play_button: Button = $MenuButtons/PlayButton
@onready var shop_button: Button = $MenuButtons/ShopButton
@onready var help_button: Button = $MenuButtons/HelpButton
@onready var quit_button: Button = $MenuButtons/QuitButton

@onready var shop_modal: ColorRect = $ShopModal
@onready var shop_coins_label: Label = $ShopModal/CurrencyBox/Margin/VBox/CoinsRow/ShopCoinsLabel
@onready var shop_gems_label: Label = $ShopModal/CurrencyBox/Margin/VBox/GemsRow/ShopGemsLabel
@onready var archer_tab: Button = $ShopModal/StoneFrame/StoneMargin/WoodBoard/Margin/VBox/CategoryTabs/ArcherTab
@onready var ice_tab: Button = $ShopModal/StoneFrame/StoneMargin/WoodBoard/Margin/VBox/CategoryTabs/IceTab
@onready var cannon_tab: Button = $ShopModal/StoneFrame/StoneMargin/WoodBoard/Margin/VBox/CategoryTabs/CannonTab
@onready var tesla_tab: Button = $ShopModal/StoneFrame/StoneMargin/WoodBoard/Margin/VBox/CategoryTabs/TeslaTab
@onready var owned_tab: Button = $ShopModal/StoneFrame/StoneMargin/WoodBoard/Margin/VBox/CategoryTabs/OwnedTab
@onready var shop_scroll: ScrollContainer = $ShopModal/StoneFrame/StoneMargin/WoodBoard/Margin/VBox/ShopScroll
@onready var skins_grid: GridContainer = $ShopModal/StoneFrame/StoneMargin/WoodBoard/Margin/VBox/ShopScroll/GridCenter/SkinsGrid
@onready var back_shop_button: Button = $ShopModal/StoneFrame/StoneMargin/WoodBoard/Margin/VBox/FooterRow/BackShopButton
@onready var owned_summary_label: Label = $ShopModal/StoneFrame/StoneMargin/WoodBoard/Margin/VBox/FooterRow/OwnedSummaryLabel

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

	archer_tab.pressed.connect(_on_category_selected.bind("archer"))
	ice_tab.pressed.connect(_on_category_selected.bind("ice"))
	cannon_tab.pressed.connect(_on_category_selected.bind("cannon"))
	tesla_tab.pressed.connect(_on_category_selected.bind("tesla"))
	owned_tab.pressed.connect(_on_category_selected.bind("owned"))

	back_shop_button.pressed.connect(func() -> void:
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


func _refresh_menu_ui() -> void:
	record_value_label.text = "WAVE %d" % highest_wave
	shop_coins_label.text = _format_number(shop_coins)
	shop_gems_label.text = _format_number(shop_gems)

	_update_decor_skins()
	_refresh_category_tabs()
	_rebuild_category_cards()
	_refresh_owned_summary()


func _refresh_category_tabs() -> void:
	var tab_buttons := {
		"archer": archer_tab,
		"ice": ice_tab,
		"cannon": cannon_tab,
		"tesla": tesla_tab,
		"owned": owned_tab,
	}
	for cat in CATEGORY_ORDER:
		var btn: Button = tab_buttons[cat]
		if cat == "owned":
			var owned_total: int = TOWER_ORDER.size() + owned_skins.size()
			var catalog_total: int = TOWER_ORDER.size() + SKIN_CATALOG.size()
			btn.text = "%s (%d/%d)" % [CATEGORY_LABELS[cat], owned_total, catalog_total]
		else:
			var stats := _count_category_owned(cat)
			btn.text = "%s (%d/%d)" % [CATEGORY_LABELS[cat], stats["owned"], stats["total"]]

		if cat == active_shop_category:
			if cat == "owned":
				_style_wood_button(btn, Color(0.18, 0.48, 0.34), Color(1.0, 0.84, 0.28), 3, 10)
			else:
				_style_wood_button(btn, Color(0.68, 0.42, 0.16), Color(1.0, 0.84, 0.28), 3, 10)
			btn.add_theme_color_override("font_color", Color(1.0, 0.94, 0.56))
		else:
			_style_wood_button(btn, Color(0.34, 0.21, 0.11), Color(0.18, 0.10, 0.04), 3, 10)
			btn.add_theme_color_override("font_color", Color(0.92, 0.86, 0.74))


func _count_category_owned(cat: String) -> Dictionary:
	var total: int = 0
	var owned: int = 0
	for skin in SKIN_CATALOG:
		if String(skin["tower_type"]) == cat:
			total += 1
			if owned_skins.has(String(skin["id"])):
				owned += 1
	return {"owned": owned, "total": total}


func _refresh_owned_summary() -> void:
	if active_shop_category == "owned":
		var owned_total: int = TOWER_ORDER.size() + owned_skins.size()
		var catalog_total: int = TOWER_ORDER.size() + SKIN_CATALOG.size()
		owned_summary_label.text = "Koleksi: %d/%d (4 Standar + %d Skin)" % [owned_total, catalog_total, owned_skins.size()]
		return

	var stats := _count_category_owned(active_shop_category)
	var eq_id: String = String(equipped_skins.get(active_shop_category, ""))
	var eq_name := "Standar"
	if eq_id != "":
		var eq_skin := _find_skin_by_id(eq_id)
		if not eq_skin.is_empty():
			eq_name = String(eq_skin["name"])
	owned_summary_label.text = "Dimiliki: %d/%d | Dipakai: %s" % [stats["owned"], stats["total"], eq_name]


func _rebuild_category_cards() -> void:
	for child in skins_grid.get_children():
		skins_grid.remove_child(child)
		child.queue_free()

	if active_shop_category == "owned":
		skins_grid.columns = 4
		skins_grid.add_theme_constant_override("h_separation", 14)
		skins_grid.add_theme_constant_override("v_separation", 14)
		var card_sz := Vector2(188, 198)
		for tower_type in TOWER_ORDER:
			var std_card := _create_standard_card(tower_type, card_sz)
			skins_grid.add_child(std_card)
			for skin in SKIN_CATALOG:
				if String(skin["tower_type"]) == tower_type and owned_skins.has(String(skin["id"])):
					var owned_card := _create_skin_card(skin, true, card_sz)
					skins_grid.add_child(owned_card)
	else:
		skins_grid.columns = 2
		skins_grid.add_theme_constant_override("h_separation", 22)
		skins_grid.add_theme_constant_override("v_separation", 14)
		var shop_sz := Vector2(252, 196)
		for skin in SKIN_CATALOG:
			if String(skin["tower_type"]) == active_shop_category:
				var card := _create_skin_card(skin, false, shop_sz)
				skins_grid.add_child(card)


func _create_standard_card(tower_type: String, card_size: Vector2) -> PanelContainer:
	var is_equipped: bool = String(equipped_skins.get(tower_type, "")) == ""

	var card := PanelContainer.new()
	card.custom_minimum_size = card_size
	_style_skin_card(card, Color(0.96, 0.82, 0.28) if is_equipped else Color(0.45, 0.76, 0.48))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	var tower_lbl := Label.new()
	tower_lbl.text = String(CATEGORY_LABELS.get(tower_type, tower_type.capitalize()))
	tower_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tower_lbl.add_theme_color_override("font_color", Color(0.90, 0.83, 0.68))
	tower_lbl.add_theme_color_override("font_outline_color", Color(0.14, 0.07, 0.03))
	tower_lbl.add_theme_constant_override("outline_size", 2)
	tower_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(tower_lbl)

	var name_lbl := Label.new()
	name_lbl.text = "Standar"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_color_override("font_color", Color(0.96, 0.94, 0.86))
	name_lbl.add_theme_color_override("font_outline_color", Color(0.14, 0.07, 0.03))
	name_lbl.add_theme_constant_override("outline_size", 3)
	name_lbl.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_lbl)

	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(94, 94)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.texture = TOWER_DEFAULT_TEXTURES.get(tower_type, null) as Texture2D
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(preview)

	var action_btn := Button.new()
	action_btn.custom_minimum_size = Vector2(154, 36)
	action_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	action_btn.pressed.connect(_on_standard_skin_selected.bind(tower_type))
	vbox.add_child(action_btn)

	var center_row := HBoxContainer.new()
	center_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_row.alignment = BoxContainer.ALIGNMENT_CENTER
	center_row.add_theme_constant_override("separation", 6)
	action_btn.add_child(center_row)

	var status_lbl := Label.new()
	status_lbl.add_theme_color_override("font_outline_color", Color(0.2, 0.08, 0.02))
	status_lbl.add_theme_constant_override("outline_size", 4)
	status_lbl.add_theme_font_size_override("font_size", 15)
	center_row.add_child(status_lbl)

	if is_equipped:
		status_lbl.text = "DIPAKAI"
		status_lbl.add_theme_color_override("font_color", Color(1.0, 0.94, 0.56))
		_style_wood_button(action_btn, Color(0.16, 0.48, 0.66), Color(0.98, 0.84, 0.30), 3, 10)
	else:
		status_lbl.text = "PAKAI"
		status_lbl.add_theme_color_override("font_color", Color(1.0, 0.97, 0.88))
		_style_wood_button(action_btn, Color(0.20, 0.58, 0.30), Color(0.08, 0.25, 0.12), 3, 10)

	return card


func _create_skin_card(skin: Dictionary, show_tower_badge: bool, card_size: Vector2) -> PanelContainer:
	var skin_id: String = String(skin["id"])
	var tower_type: String = String(skin["tower_type"])
	var currency: String = String(skin["currency"])
	var price: int = int(skin["price"])
	var skin_name: String = String(skin["name"])
	var name_col: Color = skin.get("name_color", Color(0.98, 0.9, 0.72))

	var is_owned: bool = owned_skins.has(skin_id)
	var is_equipped: bool = String(equipped_skins.get(tower_type, "")) == skin_id

	var card := PanelContainer.new()
	card.custom_minimum_size = card_size
	_style_skin_card(card, Color(0.96, 0.82, 0.28) if is_equipped else (Color(0.45, 0.76, 0.48) if is_owned else Color(0.56, 0.57, 0.54)))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3 if show_tower_badge else 4)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	if show_tower_badge:
		var tower_lbl := Label.new()
		tower_lbl.text = String(CATEGORY_LABELS.get(tower_type, tower_type.capitalize()))
		tower_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tower_lbl.add_theme_color_override("font_color", Color(0.90, 0.83, 0.68))
		tower_lbl.add_theme_color_override("font_outline_color", Color(0.14, 0.07, 0.03))
		tower_lbl.add_theme_constant_override("outline_size", 2)
		tower_lbl.add_theme_font_size_override("font_size", 11)
		vbox.add_child(tower_lbl)

	var name_lbl := Label.new()
	name_lbl.text = skin_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_color_override("font_color", name_col)
	name_lbl.add_theme_color_override("font_outline_color", Color(0.14, 0.07, 0.03))
	name_lbl.add_theme_constant_override("outline_size", 3)
	name_lbl.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_lbl)

	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(94, 94) if show_tower_badge else Vector2(108, 108)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.texture = skin["texture"] as Texture2D
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(preview)

	var buy_btn := Button.new()
	buy_btn.custom_minimum_size = Vector2(154, 36) if show_tower_badge else Vector2(174, 38)
	buy_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buy_btn.pressed.connect(_on_skin_action_pressed.bind(skin_id))
	vbox.add_child(buy_btn)

	var center_row := HBoxContainer.new()
	center_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_row.alignment = BoxContainer.ALIGNMENT_CENTER
	center_row.add_theme_constant_override("separation", 6)
	buy_btn.add_child(center_row)

	var status_lbl := Label.new()
	status_lbl.add_theme_color_override("font_outline_color", Color(0.2, 0.08, 0.02))
	status_lbl.add_theme_constant_override("outline_size", 4)
	status_lbl.add_theme_font_size_override("font_size", 15 if show_tower_badge else 16)
	center_row.add_child(status_lbl)

	if is_equipped:
		status_lbl.text = "DIPAKAI"
		status_lbl.add_theme_color_override("font_color", Color(1.0, 0.94, 0.56))
		_style_wood_button(buy_btn, Color(0.16, 0.48, 0.66), Color(0.98, 0.84, 0.30), 3, 10)
	elif is_owned:
		status_lbl.text = "PAKAI"
		status_lbl.add_theme_color_override("font_color", Color(1.0, 0.97, 0.88))
		_style_wood_button(buy_btn, Color(0.20, 0.58, 0.30), Color(0.08, 0.25, 0.12), 3, 10)
	else:
		var can_afford: bool = (shop_coins >= price) if currency == "coins" else (shop_gems >= price)
		status_lbl.text = "BELI"
		status_lbl.add_theme_color_override("font_color", Color(1.0, 0.97, 0.88))

		var curr_icon := TextureRect.new()
		curr_icon.custom_minimum_size = Vector2(20, 20)
		curr_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		curr_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		curr_icon.texture = ICON_COIN if currency == "coins" else ICON_GEM
		curr_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		curr_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		center_row.add_child(curr_icon)

		var price_lbl := Label.new()
		price_lbl.text = _format_number(price)
		price_lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.82))
		price_lbl.add_theme_color_override("font_outline_color", Color(0.2, 0.08, 0.02))
		price_lbl.add_theme_constant_override("outline_size", 4)
		price_lbl.add_theme_font_size_override("font_size", 17)
		center_row.add_child(price_lbl)

		buy_btn.disabled = not can_afford
		if can_afford:
			buy_btn.modulate = Color.WHITE
			_style_wood_button(buy_btn, Color(0.84, 0.41, 0.14), Color(0.28, 0.11, 0.03), 3, 10)
		else:
			buy_btn.modulate = Color(0.78, 0.75, 0.72, 0.9)
			_style_wood_button(buy_btn, Color(0.45, 0.25, 0.14), Color(0.22, 0.11, 0.05), 3, 10)

	return card


func _on_standard_skin_selected(tower_type: String) -> void:
	_play_click()
	if String(equipped_skins.get(tower_type, "")) != "":
		equipped_skins[tower_type] = ""
		_save_data()
		_refresh_menu_ui()


func _on_category_selected(cat: String) -> void:
	if active_shop_category == cat:
		return
	active_shop_category = cat
	if shop_scroll != null:
		shop_scroll.scroll_vertical = 0
	_play_click()
	_refresh_menu_ui()


func _update_decor_skins() -> void:
	var archer_skin_id: String = String(equipped_skins.get("archer", ""))
	if archer_decor != null:
		archer_decor.texture = _find_skin_texture(archer_skin_id, TOWER_DEFAULT_TEXTURES["archer"])

	var cannon_skin_id: String = String(equipped_skins.get("cannon", ""))
	if cannon_decor != null:
		cannon_decor.texture = _find_skin_texture(cannon_skin_id, TOWER_DEFAULT_TEXTURES["cannon"])


func _find_skin_texture(skin_id: String, fallback: Texture2D) -> Texture2D:
	if skin_id == "":
		return fallback
	for skin in SKIN_CATALOG:
		if String(skin["id"]) == skin_id:
			return skin["texture"] as Texture2D
	return fallback


func _find_skin_by_id(skin_id: String) -> Dictionary:
	for skin in SKIN_CATALOG:
		if String(skin["id"]) == skin_id:
			return skin
	return {}


func _on_skin_action_pressed(skin_id: String) -> void:
	var skin := _find_skin_by_id(skin_id)
	if skin.is_empty():
		return

	var tower_type: String = String(skin["tower_type"])

	if owned_skins.has(skin_id):
		if String(equipped_skins.get(tower_type, "")) == skin_id:
			equipped_skins[tower_type] = ""
		else:
			equipped_skins[tower_type] = skin_id
		_save_data()
		_play_click()
		_refresh_menu_ui()
		return

	var currency: String = String(skin["currency"])
	var price: int = int(skin["price"])

	if currency == "coins":
		if shop_coins < price:
			return
		shop_coins -= price
	else:
		if shop_gems < price:
			return
		shop_gems -= price

	owned_skins.append(skin_id)
	equipped_skins[tower_type] = skin_id
	_save_data()
	_play_upgrade()
	_refresh_menu_ui()


func _format_number(val: int) -> String:
	var s := str(val)
	if s.length() <= 3:
		return s
	var parts: Array[String] = []
	while s.length() > 3:
		parts.insert(0, s.substr(s.length() - 3, 3))
		s = s.substr(0, s.length() - 3)
	parts.insert(0, s)
	return ".".join(parts)


func _on_play_pressed() -> void:
	_play_click()
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _on_shop_pressed() -> void:
	_play_click()
	if shop_scroll != null:
		shop_scroll.scroll_vertical = 0
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
	shop_coins = DEFAULT_SHOP_COINS
	shop_gems = DEFAULT_SHOP_GEMS
	_skin_pack_v2_bonus = true
	owned_skins.clear()
	equipped_skins = {
		"archer": "",
		"ice": "",
		"cannon": "",
		"tesla": "",
	}
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
		shop_coins = int(config.get_value("wallet", "shop_coins", DEFAULT_SHOP_COINS))
		shop_gems = int(config.get_value("wallet", "shop_gems", DEFAULT_SHOP_GEMS))
		_skin_pack_v2_bonus = bool(config.get_value("wallet", "skin_pack_v2_bonus", false))

		owned_skins.clear()
		var loaded_owned: Variant = config.get_value("skins", "owned", [])
		if loaded_owned is Array:
			for s in loaded_owned:
				var sid := String(s)
				if sid != "" and not _find_skin_by_id(sid).is_empty() and not owned_skins.has(sid):
					owned_skins.append(sid)

		var loaded_eq: Variant = config.get_value("skins", "equipped", {})
		if loaded_eq is Dictionary:
			for k in equipped_skins.keys():
				var eq_id: String = String(loaded_eq.get(k, ""))
				if eq_id != "" and owned_skins.has(eq_id):
					equipped_skins[k] = eq_id
				else:
					equipped_skins[k] = ""

		if not _skin_pack_v2_bonus:
			_skin_pack_v2_bonus = true
			shop_coins = maxi(shop_coins, DEFAULT_SHOP_COINS) + 150
			shop_gems = maxi(shop_gems, DEFAULT_SHOP_GEMS) + 30
			_save_data()


func _save_data() -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("progress", "highest_wave", highest_wave)
	config.set_value("wallet", "shop_coins", shop_coins)
	config.set_value("wallet", "shop_gems", shop_gems)
	config.set_value("wallet", "skin_pack_v2_bonus", _skin_pack_v2_bonus)
	config.set_value("skins", "owned", owned_skins.duplicate())
	config.set_value("skins", "equipped", equipped_skins.duplicate())
	config.save(SAVE_PATH)


func _apply_wooden_theme() -> void:
	_style_wood_button(play_button, Color(0.46, 0.28, 0.13), Color(0.95, 0.76, 0.22), 5, 14)
	for btn in [shop_button, help_button, quit_button, settings_button]:
		_style_wood_button(btn, Color(0.47, 0.29, 0.15), Color(0.20, 0.11, 0.05), 4, 12)

	_style_wood_button(back_shop_button, Color(0.68, 0.18, 0.15), Color(0.24, 0.06, 0.05), 4, 10)

	for panel in [
		$RecordBoard,
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

	var stone_sb := StyleBoxFlat.new()
	stone_sb.bg_color = Color(0.28, 0.30, 0.28)
	stone_sb.border_color = Color(0.13, 0.15, 0.13)
	stone_sb.set_border_width_all(5)
	stone_sb.set_corner_radius_all(16)
	stone_sb.shadow_color = Color(0, 0, 0, 0.55)
	stone_sb.shadow_size = 10
	$ShopModal/StoneFrame.add_theme_stylebox_override("panel", stone_sb)

	var wood_sb := StyleBoxFlat.new()
	wood_sb.bg_color = Color(0.45, 0.27, 0.14)
	wood_sb.border_color = Color(0.20, 0.11, 0.05)
	wood_sb.set_border_width_all(4)
	wood_sb.set_corner_radius_all(10)
	$ShopModal/StoneFrame/StoneMargin/WoodBoard.add_theme_stylebox_override("panel", wood_sb)

	var title_sb := StyleBoxFlat.new()
	title_sb.bg_color = Color(0.52, 0.32, 0.15)
	title_sb.border_color = Color(0.22, 0.11, 0.04)
	title_sb.set_border_width_all(5)
	title_sb.set_corner_radius_all(12)
	title_sb.shadow_color = Color(0, 0, 0, 0.48)
	title_sb.shadow_size = 6
	$ShopModal/TitleBanner.add_theme_stylebox_override("panel", title_sb)

	var curr_sb := StyleBoxFlat.new()
	curr_sb.bg_color = Color(0.46, 0.28, 0.14)
	curr_sb.border_color = Color(0.20, 0.11, 0.05)
	curr_sb.set_border_width_all(4)
	curr_sb.set_corner_radius_all(10)
	curr_sb.shadow_color = Color(0, 0, 0, 0.45)
	curr_sb.shadow_size = 5
	$ShopModal/CurrencyBox.add_theme_stylebox_override("panel", curr_sb)


func _style_skin_card(card: PanelContainer, border_col: Color) -> void:
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color(0.36, 0.22, 0.13)
	card_sb.border_color = border_col
	card_sb.set_border_width_all(6)
	card_sb.set_corner_radius_all(10)
	card_sb.shadow_color = Color(0, 0, 0, 0.4)
	card_sb.shadow_size = 4
	card.add_theme_stylebox_override("panel", card_sb)


func _style_wood_button(btn: Button, fill: Color, border: Color, border_w: int, radius: int) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = fill
	normal.border_color = border
	normal.set_border_width_all(border_w)
	normal.set_corner_radius_all(radius)
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	normal.shadow_color = Color(0, 0, 0, 0.45)
	normal.shadow_size = 5
	normal.shadow_offset = Vector2(0, 3)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = fill.lightened(0.12)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = fill.darkened(0.12)
	pressed.shadow_offset = Vector2(0, 1)

	var disabled_sb := normal.duplicate() as StyleBoxFlat
	disabled_sb.bg_color = fill.darkened(0.15)
	disabled_sb.shadow_size = 2

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_stylebox_override("disabled", disabled_sb)
