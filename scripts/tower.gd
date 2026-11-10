extends Node2D

const TOWER_TEXTURES := {
	"archer": preload("res://assets/images/archer_tower.png"),
	"ice": preload("res://assets/images/ice_tower.png"),
	"cannon": preload("res://assets/images/cannon_tower.png"),
	"tesla": preload("res://assets/images/tesla_tower.png"),
}

const TOWER_SOUNDS := {
	"archer": preload("res://assets/sounds/shoot_archer.wav"),
	"ice": preload("res://assets/sounds/shoot_ice.wav"),
	"cannon": preload("res://assets/sounds/shoot_cannon.wav"),
	"tesla": preload("res://assets/sounds/shoot_tesla.wav"),
}

const TOWER_CONFIGS := {
	"archer": {
		"name": "Archer Tower",
		"cost": 50,
		"damage": 18.0,
		"range": 185.0,
		"fire_rate": 1.8,
		"dmg_inc": 10.0,
		"rng_inc": 28.0,
		"dmg_cost": 35,
		"rng_cost": 30,
		"proj_type": "arrow",
		"proj_speed": 500.0,
		"slow_factor": 1.0,
		"slow_duration": 0.0,
		"splash_radius": 0.0,
		"chain_count": 0,
	},
	"ice": {
		"name": "Ice Tower",
		"cost": 70,
		"damage": 12.0,
		"range": 155.0,
		"fire_rate": 1.0,
		"dmg_inc": 7.0,
		"rng_inc": 26.0,
		"dmg_cost": 40,
		"rng_cost": 35,
		"proj_type": "ice",
		"proj_speed": 380.0,
		"slow_factor": 0.55,
		"slow_duration": 2.2,
		"splash_radius": 0.0,
		"chain_count": 0,
	},
	"cannon": {
		"name": "Cannon Tower",
		"cost": 90,
		"damage": 38.0,
		"range": 150.0,
		"fire_rate": 0.65,
		"dmg_inc": 18.0,
		"rng_inc": 25.0,
		"dmg_cost": 50,
		"rng_cost": 40,
		"proj_type": "cannon",
		"proj_speed": 330.0,
		"slow_factor": 1.0,
		"slow_duration": 0.0,
		"splash_radius": 68.0,
		"chain_count": 0,
	},
	"tesla": {
		"name": "Tesla Tower",
		"cost": 110,
		"damage": 26.0,
		"range": 165.0,
		"fire_rate": 1.45,
		"dmg_inc": 13.0,
		"rng_inc": 28.0,
		"dmg_cost": 55,
		"rng_cost": 45,
		"proj_type": "tesla",
		"proj_speed": 580.0,
		"slow_factor": 1.0,
		"slow_duration": 0.0,
		"splash_radius": 0.0,
		"chain_count": 2,
	},
}

@export var projectile_scene: PackedScene
@export var tower_type: String = "archer"
@export var tower_display_name: String = "Archer Tower"
@export var attack_damage: float = 18.0
@export var attack_range: float = 185.0
@export var fire_rate: float = 1.8
@export var build_cost: int = 50
@export var base_damage_upgrade_cost: int = 35
@export var base_range_upgrade_cost: int = 30
@export var damage_upgrade_increment: float = 10.0
@export var range_upgrade_increment: float = 28.0
@export var max_damage_level: int = 5
@export var max_range_level: int = 5
@export var show_placeholder: bool = true

var projectile_type: String = "arrow"
var projectile_speed: float = 500.0
var slow_factor: float = 1.0
var slow_duration: float = 0.0
var splash_radius: float = 0.0
var chain_count: int = 0

var damage_level: int = 1
var range_level: int = 1
var total_invested: int = 50
var is_selected: bool = false
var projectile_parent: Node = null
var _cooldown_timer: float = 0.0
var _base_sprite_scale: Vector2 = Vector2(0.62, 0.62)

@onready var base_sprite: Sprite2D = $BaseSprite
@onready var turret_pivot: Node2D = $TurretPivot
@onready var turret_sprite: Sprite2D = $TurretPivot/TurretSprite
@onready var muzzle: Marker2D = $TurretPivot/Muzzle
@onready var range_area: Area2D = $RangeArea
@onready var range_shape: CollisionShape2D = $RangeArea/RangeShape
@onready var shoot_sound: AudioStreamPlayer2D = $ShootSound


func _ready() -> void:
	# Duplikasi shape agar setiap instance tower punya radius jangkauan masing-masing.
	if range_shape.shape != null:
		range_shape.shape = range_shape.shape.duplicate()
	else:
		range_shape.shape = CircleShape2D.new()

	if base_sprite != null:
		_base_sprite_scale = base_sprite.scale
	_apply_tower_visual()
	_apply_range_radius()
	queue_redraw()


func configure_tower(type_id: String) -> void:
	if not TOWER_CONFIGS.has(type_id):
		return
	var cfg: Dictionary = TOWER_CONFIGS[type_id]
	tower_type = type_id
	tower_display_name = cfg["name"]
	build_cost = cfg["cost"]
	total_invested = build_cost
	attack_damage = cfg["damage"]
	attack_range = cfg["range"]
	fire_rate = cfg["fire_rate"]
	damage_upgrade_increment = cfg["dmg_inc"]
	range_upgrade_increment = cfg["rng_inc"]
	base_damage_upgrade_cost = cfg["dmg_cost"]
	base_range_upgrade_cost = cfg["rng_cost"]
	projectile_type = cfg["proj_type"]
	projectile_speed = cfg["proj_speed"]
	slow_factor = cfg["slow_factor"]
	slow_duration = cfg["slow_duration"]
	splash_radius = cfg["splash_radius"]
	chain_count = cfg["chain_count"]

	if is_node_ready():
		_apply_tower_visual()
		_apply_range_radius()
		queue_redraw()


func _physics_process(delta: float) -> void:
	_cooldown_timer = maxf(0.0, _cooldown_timer - delta)

	var target: Node2D = _find_furthest_enemy_in_range()
	if target == null:
		return

	if turret_sprite != null and turret_sprite.texture != null:
		var target_angle: float = (target.global_position - global_position).angle()
		turret_pivot.rotation = target_angle

	if _cooldown_timer <= 0.0:
		_shoot(target)
		_cooldown_timer = 1.0 / maxf(fire_rate, 0.05)


func _find_furthest_enemy_in_range() -> Node2D:
	var best_enemy: Node2D = null
	var best_progress: float = -1.0

	for area in range_area.get_overlapping_areas():
		var enemy := area.get_parent() as PathFollow2D
		if enemy == null or not enemy.is_in_group("enemies"):
			continue
		if enemy.is_queued_for_deletion() or (enemy.has_method("is_dead") and enemy.is_dead()):
			continue
		if enemy.progress > best_progress:
			best_progress = enemy.progress
			best_enemy = enemy

	return best_enemy


func _shoot(target: Node2D) -> void:
	if projectile_scene == null:
		return

	var projectile := projectile_scene.instantiate()
	var parent_node: Node = projectile_parent if is_instance_valid(projectile_parent) else get_tree().current_scene
	parent_node.add_child(projectile)
	projectile.global_position = muzzle.global_position

	var direction: Vector2 = (target.global_position - muzzle.global_position).normalized()
	if projectile.has_method("setup"):
		projectile.setup(
			target,
			attack_damage,
			direction,
			projectile_type,
			projectile_speed,
			slow_factor,
			slow_duration,
			splash_radius,
			chain_count
		)

	_play_shoot_pulse()

	if shoot_sound != null and shoot_sound.stream != null:
		shoot_sound.pitch_scale = randf_range(0.95, 1.05)
		shoot_sound.play()


func _play_shoot_pulse() -> void:
	if base_sprite == null or base_sprite.texture == null:
		return
	var tween := create_tween()
	base_sprite.scale = Vector2(_base_sprite_scale.x * 1.07, _base_sprite_scale.y * 0.93)
	tween.tween_property(base_sprite, "scale", _base_sprite_scale, 0.12)


func get_damage_upgrade_cost() -> int:
	return base_damage_upgrade_cost * damage_level


func get_range_upgrade_cost() -> int:
	return base_range_upgrade_cost * range_level


func can_upgrade_damage() -> bool:
	return damage_level < max_damage_level


func can_upgrade_range() -> bool:
	return range_level < max_range_level


func upgrade_damage() -> void:
	if not can_upgrade_damage():
		return
	total_invested += get_damage_upgrade_cost()
	damage_level += 1
	attack_damage += damage_upgrade_increment
	queue_redraw()


func upgrade_range() -> void:
	if not can_upgrade_range():
		return
	total_invested += get_range_upgrade_cost()
	range_level += 1
	attack_range += range_upgrade_increment
	_apply_range_radius()
	queue_redraw()


func get_sell_value() -> int:
	return int(round(total_invested * 0.7))


func set_selected(selected: bool) -> void:
	is_selected = selected
	queue_redraw()


func _apply_tower_visual() -> void:
	if base_sprite != null and TOWER_TEXTURES.has(tower_type):
		base_sprite.texture = TOWER_TEXTURES[tower_type]
	if shoot_sound != null and TOWER_SOUNDS.has(tower_type):
		shoot_sound.stream = TOWER_SOUNDS[tower_type]


func _apply_range_radius() -> void:
	if range_shape != null and range_shape.shape is CircleShape2D:
		(range_shape.shape as CircleShape2D).radius = attack_range


func _should_draw_placeholder() -> bool:
	if not show_placeholder:
		return false
	var has_base: bool = base_sprite != null and base_sprite.texture != null
	var has_turret: bool = turret_sprite != null and turret_sprite.texture != null
	return not has_base and not has_turret


func _draw() -> void:
	if is_selected:
		draw_circle(Vector2.ZERO, attack_range, Color(0.3, 0.75, 1.0, 0.12))
		draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, 48, Color(0.3, 0.85, 1.0, 0.85), 2.0)
		draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 24, Color(1.0, 0.95, 0.4, 0.9), 2.5)

	if not _should_draw_placeholder():
		return

	draw_circle(Vector2.ZERO, 20.0, Color(0.2, 0.55, 0.9))
	draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 24, Color.WHITE, 2.0)
