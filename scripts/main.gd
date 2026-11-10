extends Node2D

const SAVE_PATH := "user://save_data.cfg"
const MENU_SCENE_PATH := "res://scenes/MainMenu.tscn"

const SFX_BUILD := preload("res://assets/sounds/build_tower.wav")
const SFX_UPGRADE := preload("res://assets/sounds/upgrade_tower.wav")
const SFX_COIN := preload("res://assets/sounds/enemy_defeated.wav")
const SFX_LIFE_LOST := preload("res://assets/sounds/life_lost.wav")
const SFX_WAVE_START := preload("res://assets/sounds/wave_start.wav")
const SFX_WAVE_CLEAR := preload("res://assets/sounds/wave_clear.wav")
const SFX_GAME_OVER := preload("res://assets/sounds/game_over.wav")

const TOWER_MENU := {
	"archer": {"name": "Archer", "cost": 50, "range": 185.0},
	"ice": {"name": "Ice", "cost": 70, "range": 155.0},
	"cannon": {"name": "Cannon", "cost": 90, "range": 150.0},
	"tesla": {"name": "Tesla", "cost": 110, "range": 165.0},
}

@export var enemy_scene: PackedScene
@export var tower_scene: PackedScene
@export var starting_coins: int = 150
@export var starting_lives: int = 10
@export var path_clearance: float = 44.0
@export var tower_spacing: float = 48.0
@export var map_margin: float = 24.0
@export var top_ui_clearance: float = 76.0

var coins: int = 150
var lives: int = 10
var current_wave: int = 0
var highest_wave: int = 0
var bonus_coins_lv: int = 0
var bonus_lives_lv: int = 0
var bonus_damage_lv: int = 0
var is_wave_active: bool = false
var is_game_over: bool = false
var build_mode: bool = true
var selected_tower_type: String = "archer"
var selected_tower: Node2D = null

var _enemies_to_spawn: int = 0
var _active_enemies: int = 0
var _hover_world_pos: Vector2 = Vector2.ZERO
var _is_mouse_on_map: bool = false
var _message_timer: float = 0.0

@onready var map_background: Sprite2D = $MapBackground
@onready var path_visual: Line2D = $PathVisual
@onready var enemy_path: Path2D = $EnemyPath
@onready var towers_container: Node2D = $Towers
@onready var projectiles_container: Node2D = $Projectiles
@onready var placement_preview: Node2D = $PlacementPreview
@onready var spawn_timer: Timer = $SpawnTimer
@onready var bgm_player: AudioStreamPlayer = $BgmPlayer
@onready var sfx_player: AudioStreamPlayer = $SfxPlayer

@onready var coins_label: Label = $HUD/TopBar/Margin/HBox/CoinsLabel
@onready var lives_label: Label = $HUD/TopBar/Margin/HBox/LivesLabel
@onready var wave_label: Label = $HUD/TopBar/Margin/HBox/WaveLabel
@onready var best_wave_label: Label = $HUD/TopBar/Margin/HBox/BestWaveLabel
@onready var mute_button: Button = $HUD/TopBar/Margin/HBox/MuteButton
@onready var build_mode_button: Button = $HUD/TopBar/Margin/HBox/BuildModeButton
@onready var start_wave_button: Button = $HUD/TopBar/Margin/HBox/StartWaveButton
@onready var main_menu_button: Button = $HUD/TopBar/Margin/HBox/MainMenuButton

@onready var archer_button: Button = $HUD/TowerBar/Margin/HBox/ArcherButton
@onready var ice_button: Button = $HUD/TowerBar/Margin/HBox/IceButton
@onready var cannon_button: Button = $HUD/TowerBar/Margin/HBox/CannonButton
@onready var tesla_button: Button = $HUD/TowerBar/Margin/HBox/TeslaButton

@onready var upgrade_panel: PanelContainer = $HUD/UpgradePanel
@onready var tower_info_label: Label = $HUD/UpgradePanel/Margin/VBox/TowerInfoLabel
@onready var upgrade_damage_button: Button = $HUD/UpgradePanel/Margin/VBox/Buttons/UpgradeDamageButton
@onready var upgrade_range_button: Button = $HUD/UpgradePanel/Margin/VBox/Buttons/UpgradeRangeButton
@onready var sell_button: Button = $HUD/UpgradePanel/Margin/VBox/Buttons/SellButton
@onready var close_upgrade_button: Button = $HUD/UpgradePanel/Margin/VBox/Buttons/CloseUpgradeButton

@onready var message_label: Label = $HUD/MessageLabel
@onready var game_over_panel: PanelContainer = $HUD/GameOverPanel
@onready var summary_label: Label = $HUD/GameOverPanel/Margin/VBox/SummaryLabel
@onready var restart_button: Button = $HUD/GameOverPanel/Margin/VBox/RestartButton
@onready var game_over_menu_button: Button = $HUD/GameOverPanel/Margin/VBox/MainMenuButton


func _ready() -> void:
	_load_progress()
	coins = starting_coins + bonus_coins_lv * 25
	lives = starting_lives + bonus_lives_lv * 2
	_sync_path_visual()

	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	placement_preview.draw.connect(_on_placement_preview_draw)
	bgm_player.finished.connect(_on_bgm_finished)

	mute_button.toggled.connect(_on_mute_toggled)
	build_mode_button.toggled.connect(_on_build_mode_toggled)
	start_wave_button.pressed.connect(_on_start_wave_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	archer_button.pressed.connect(_on_tower_type_selected.bind("archer"))
	ice_button.pressed.connect(_on_tower_type_selected.bind("ice"))
	cannon_button.pressed.connect(_on_tower_type_selected.bind("cannon"))
	tesla_button.pressed.connect(_on_tower_type_selected.bind("tesla"))
	upgrade_damage_button.pressed.connect(_on_upgrade_damage_pressed)
	upgrade_range_button.pressed.connect(_on_upgrade_range_pressed)
	sell_button.pressed.connect(_on_sell_tower_pressed)
	close_upgrade_button.pressed.connect(_on_close_upgrade_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	game_over_menu_button.pressed.connect(_on_main_menu_pressed)

	var sound_on: bool = not AudioServer.is_bus_mute(0)
	mute_button.set_pressed_no_signal(sound_on)
	mute_button.text = "Suara: ON" if sound_on else "Suara: OFF"
	build_mode_button.button_pressed = build_mode
	upgrade_panel.visible = false
	game_over_panel.visible = false
	message_label.visible = false

	_refresh_ui()
	_show_message("Klik area di luar jalur untuk membangun tower, lalu tekan Mulai Wave.")


func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			message_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if is_game_over:
		return

	if event is InputEventMouseMotion:
		_hover_world_pos = get_global_mouse_position()
		_is_mouse_on_map = true
		placement_preview.queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var click_pos: Vector2 = get_global_mouse_position()
			var clicked_tower: Node2D = _find_tower_at(click_pos)
			if clicked_tower != null:
				_select_tower(clicked_tower)
				return

			if build_mode:
				_try_build_tower(click_pos)
			else:
				_select_tower(null)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_select_tower(null)


func _sync_path_visual() -> void:
	if enemy_path == null or enemy_path.curve == null or path_visual == null:
		return
	path_visual.global_position = enemy_path.global_position
	path_visual.points = enemy_path.curve.get_baked_points()
	path_visual.visible = (map_background == null or map_background.texture == null)


func _find_tower_at(world_pos: Vector2) -> Node2D:
	var children := towers_container.get_children()
	for i in range(children.size() - 1, -1, -1):
		var child := children[i]
		if child is Node2D and not child.is_queued_for_deletion():
			var diff: Vector2 = world_pos - child.global_position
			if absf(diff.x) <= 28.0 and diff.y >= -82.0 and diff.y <= 18.0:
				return child
	return null


func is_valid_tower_position(world_pos: Vector2) -> bool:
	var viewport_size: Vector2 = get_viewport_rect().size
	if world_pos.x < map_margin or world_pos.x > viewport_size.x - map_margin:
		return false
	if world_pos.y < top_ui_clearance or world_pos.y > viewport_size.y - map_margin:
		return false

	if enemy_path != null and enemy_path.curve != null:
		var local_pos: Vector2 = enemy_path.to_local(world_pos)
		var closest_point: Vector2 = enemy_path.curve.get_closest_point(local_pos)
		if local_pos.distance_to(closest_point) < path_clearance:
			return false

	for child in towers_container.get_children():
		if child is Node2D and not child.is_queued_for_deletion():
			if world_pos.distance_to(child.global_position) < tower_spacing:
				return false

	return true


func _try_build_tower(world_pos: Vector2) -> void:
	if tower_scene == null:
		return

	if not is_valid_tower_position(world_pos):
		_show_message("Tidak bisa menempatkan tower di jalur monster atau terlalu dekat tower lain.")
		return

	var cfg: Dictionary = TOWER_MENU.get(selected_tower_type, TOWER_MENU["archer"])
	var cost: int = int(cfg["cost"])
	if coins < cost:
		_show_message("Koin tidak cukup! Butuh %d koin untuk %s Tower." % [cost, cfg["name"]])
		return

	coins -= cost
	var tower := tower_scene.instantiate() as Node2D
	towers_container.add_child(tower)
	tower.global_position = world_pos
	tower.set("projectile_parent", projectiles_container)
	if tower.has_method("configure_tower"):
		tower.configure_tower(selected_tower_type)
	if bonus_damage_lv > 0:
		tower.attack_damage *= (1.0 + 0.10 * float(bonus_damage_lv))

	_play_sfx(SFX_BUILD)
	_select_tower(tower)
	_refresh_ui()
	placement_preview.queue_redraw()


func _select_tower(tower: Node2D) -> void:
	if is_instance_valid(selected_tower) and selected_tower.has_method("set_selected"):
		selected_tower.set_selected(false)

	selected_tower = tower
	if is_instance_valid(selected_tower) and selected_tower.has_method("set_selected"):
		selected_tower.set_selected(true)

	_refresh_ui()
	placement_preview.queue_redraw()


func _on_start_wave_pressed() -> void:
	if is_wave_active or is_game_over:
		return

	current_wave += 1
	is_wave_active = true
	_enemies_to_spawn = 4 + current_wave * 2
	spawn_timer.wait_time = maxf(0.35, 1.15 - float(current_wave - 1) * 0.08)

	_play_sfx(SFX_WAVE_START)
	_spawn_next_enemy()
	if _enemies_to_spawn > 0:
		spawn_timer.start()

	_refresh_ui()


func _on_spawn_timer_timeout() -> void:
	if is_game_over or _enemies_to_spawn <= 0:
		spawn_timer.stop()
		return

	_spawn_next_enemy()
	if _enemies_to_spawn <= 0:
		spawn_timer.stop()


func _spawn_next_enemy() -> void:
	if enemy_scene == null or _enemies_to_spawn <= 0:
		return

	_enemies_to_spawn -= 1
	_active_enemies += 1

	var is_final: bool = (_enemies_to_spawn == 0)
	var is_boss: bool = (current_wave % 5 == 0) and is_final
	var type_id: String = _pick_enemy_type_for_wave(current_wave, is_final)
	var base_hp: float = 55.0 * pow(1.20, float(current_wave - 1))
	var base_speed: float = minf(185.0, 92.0 + float(current_wave - 1) * 7.0)
	var base_reward: int = 12 + int(current_wave / 2)

	var enemy := enemy_scene.instantiate()
	enemy_path.add_child(enemy)
	if enemy.has_method("setup"):
		enemy.setup(base_hp, base_speed, base_reward, 1, is_boss, type_id)
	enemy.defeated.connect(_on_enemy_defeated)
	enemy.reached_goal.connect(_on_enemy_reached_goal)


func _pick_enemy_type_for_wave(wave: int, is_final_in_wave: bool) -> String:
	if wave % 5 == 0 and is_final_in_wave:
		return "boss_troll"
	var pool: Array[String] = ["slime", "goblin"]
	if wave >= 2:
		pool.append("orc")
	if wave >= 3:
		pool.append("golem")
	return pool[_enemies_to_spawn % pool.size()]


func _on_enemy_defeated(coin_reward: int) -> void:
	if is_game_over:
		return

	coins += coin_reward
	_active_enemies = maxi(0, _active_enemies - 1)
	_play_sfx(SFX_COIN, randf_range(0.96, 1.06))
	_check_wave_completed()
	_refresh_ui()


func _on_enemy_reached_goal(life_damage: int) -> void:
	if is_game_over:
		return

	lives = maxi(0, lives - life_damage)
	_active_enemies = maxi(0, _active_enemies - 1)
	_play_sfx(SFX_LIFE_LOST)

	if lives <= 0:
		_trigger_game_over()
		return

	_check_wave_completed()
	_refresh_ui()


func _check_wave_completed() -> void:
	if not is_wave_active or is_game_over:
		return
	if _enemies_to_spawn > 0 or _active_enemies > 0:
		return

	is_wave_active = false
	var bonus: int = 20 + current_wave * 5
	coins += bonus

	if current_wave > highest_wave:
		highest_wave = current_wave
		_save_progress()

	_play_sfx(SFX_WAVE_CLEAR)
	_show_message("Wave %d selesai! Bonus +%d koin." % [current_wave, bonus])


func _trigger_game_over() -> void:
	is_game_over = true
	is_wave_active = false
	spawn_timer.stop()
	_select_tower(null)
	_play_sfx(SFX_GAME_OVER)

	summary_label.text = "Wave Dicapai: %d\nRekor Wave Selesai: %d" % [current_wave, highest_wave]
	game_over_panel.visible = true
	_refresh_ui()


func _on_bgm_finished() -> void:
	if bgm_player != null:
		bgm_player.play()


func _on_mute_toggled(sound_on: bool) -> void:
	AudioServer.set_bus_mute(0, not sound_on)
	mute_button.text = "Suara: ON" if sound_on else "Suara: OFF"


func _play_sfx(stream: AudioStream, pitch: float = 1.0) -> void:
	if sfx_player == null or stream == null:
		return
	sfx_player.stream = stream
	sfx_player.pitch_scale = pitch
	sfx_player.play()


func _on_build_mode_toggled(toggled_on: bool) -> void:
	build_mode = toggled_on
	_refresh_ui()
	placement_preview.queue_redraw()


func _on_tower_type_selected(type_id: String) -> void:
	selected_tower_type = type_id
	build_mode = true
	build_mode_button.set_pressed_no_signal(true)
	_refresh_ui()
	placement_preview.queue_redraw()


func _on_upgrade_damage_pressed() -> void:
	if not is_instance_valid(selected_tower):
		return
	if not selected_tower.can_upgrade_damage():
		return

	var cost: int = selected_tower.get_damage_upgrade_cost()
	if coins < cost:
		_show_message("Koin tidak cukup untuk upgrade damage!")
		return

	coins -= cost
	selected_tower.upgrade_damage()
	_play_sfx(SFX_UPGRADE)
	_refresh_ui()


func _on_upgrade_range_pressed() -> void:
	if not is_instance_valid(selected_tower):
		return
	if not selected_tower.can_upgrade_range():
		return

	var cost: int = selected_tower.get_range_upgrade_cost()
	if coins < cost:
		_show_message("Koin tidak cukup untuk upgrade jangkauan!")
		return

	coins -= cost
	selected_tower.upgrade_range()
	_play_sfx(SFX_UPGRADE)
	_refresh_ui()


func _on_sell_tower_pressed() -> void:
	if not is_instance_valid(selected_tower):
		return

	var refund: int = selected_tower.get_sell_value()
	coins += refund
	selected_tower.queue_free()
	_select_tower(null)
	_play_sfx(SFX_COIN, 0.9)
	_show_message("Tower dijual (+%d koin)." % refund)
	_refresh_ui()


func _on_close_upgrade_pressed() -> void:
	_select_tower(null)


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()


func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file(MENU_SCENE_PATH)


func _refresh_ui() -> void:
	coins_label.text = "Koin: %d" % coins
	lives_label.text = "Nyawa: %d" % lives
	wave_label.text = "Wave: %d" % current_wave
	best_wave_label.text = "Rekor: Wave %d" % highest_wave

	var active_cfg: Dictionary = TOWER_MENU.get(selected_tower_type, TOWER_MENU["archer"])
	build_mode_button.text = "Mode Bangun: ON (%s %d)" % [active_cfg["name"], active_cfg["cost"]] if build_mode else "Mode Bangun: OFF"
	archer_button.set_pressed_no_signal(build_mode and selected_tower_type == "archer")
	ice_button.set_pressed_no_signal(build_mode and selected_tower_type == "ice")
	cannon_button.set_pressed_no_signal(build_mode and selected_tower_type == "cannon")
	tesla_button.set_pressed_no_signal(build_mode and selected_tower_type == "tesla")

	start_wave_button.disabled = is_wave_active or is_game_over
	start_wave_button.text = "Wave Berjalan..." if is_wave_active else "Mulai Wave %d" % (current_wave + 1)

	if is_instance_valid(selected_tower) and not selected_tower.is_queued_for_deletion():
		upgrade_panel.visible = true
		tower_info_label.text = "%s | Damage: %.0f (Lv.%d) | Jangkauan: %.0f (Lv.%d)" % [
			selected_tower.tower_display_name,
			selected_tower.attack_damage,
			selected_tower.damage_level,
			selected_tower.attack_range,
			selected_tower.range_level
		]

		if selected_tower.can_upgrade_damage():
			var dmg_cost: int = selected_tower.get_damage_upgrade_cost()
			upgrade_damage_button.text = "+Damage (%d Koin)" % dmg_cost
			upgrade_damage_button.disabled = coins < dmg_cost
		else:
			upgrade_damage_button.text = "Damage MAX"
			upgrade_damage_button.disabled = true

		if selected_tower.can_upgrade_range():
			var rng_cost: int = selected_tower.get_range_upgrade_cost()
			upgrade_range_button.text = "+Jangkauan (%d Koin)" % rng_cost
			upgrade_range_button.disabled = coins < rng_cost
		else:
			upgrade_range_button.text = "Jangkauan MAX"
			upgrade_range_button.disabled = true

		sell_button.text = "Jual (+%d)" % selected_tower.get_sell_value()
	else:
		upgrade_panel.visible = false


func _show_message(text: String, duration: float = 2.5) -> void:
	message_label.text = text
	message_label.visible = true
	_message_timer = duration


func _on_placement_preview_draw() -> void:
	if not build_mode or is_game_over or not _is_mouse_on_map:
		return
	if get_viewport().gui_get_hovered_control() != null:
		return
	if _find_tower_at(_hover_world_pos) != null:
		return

	var cfg: Dictionary = TOWER_MENU.get(selected_tower_type, TOWER_MENU["archer"])
	var cost: int = int(cfg["cost"])
	var preview_range: float = float(cfg["range"])
	var valid: bool = is_valid_tower_position(_hover_world_pos) and coins >= cost
	var fill_color: Color = Color(0.2, 0.9, 0.35, 0.25) if valid else Color(0.95, 0.2, 0.2, 0.25)
	var line_color: Color = Color(0.2, 0.95, 0.4, 0.8) if valid else Color(0.95, 0.25, 0.25, 0.8)

	placement_preview.draw_circle(_hover_world_pos, 20.0, fill_color)
	placement_preview.draw_arc(_hover_world_pos, 20.0, 0.0, TAU, 24, line_color, 2.0)
	placement_preview.draw_arc(_hover_world_pos, preview_range, 0.0, TAU, 48, Color(line_color.r, line_color.g, line_color.b, 0.45), 1.5)


func _load_progress() -> void:
	var config := ConfigFile.new()
	var err: Error = config.load(SAVE_PATH)
	if err == OK:
		highest_wave = int(config.get_value("progress", "highest_wave", 0))
		bonus_coins_lv = int(config.get_value("shop", "bonus_coins_lv", 0))
		bonus_lives_lv = int(config.get_value("shop", "bonus_lives_lv", 0))
		bonus_damage_lv = int(config.get_value("shop", "bonus_damage_lv", 0))
	else:
		highest_wave = 0
		bonus_coins_lv = 0
		bonus_lives_lv = 0
		bonus_damage_lv = 0


func _save_progress() -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("progress", "highest_wave", highest_wave)
	config.save(SAVE_PATH)
