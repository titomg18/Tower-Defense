extends PathFollow2D

signal defeated(coin_reward: int)
signal reached_goal(life_damage: int)

const ENEMY_TEXTURES := {
	"slime": preload("res://assets/images/enemy_slime.png"),
	"goblin": preload("res://assets/images/enemy_goblin.png"),
	"orc": preload("res://assets/images/enemy_orc.png"),
	"golem": preload("res://assets/images/enemy_golem.png"),
	"boss_troll": preload("res://assets/images/enemy_boss_troll.png"),
}

const ENEMY_CONFIGS := {
	"slime": {"hp_mult": 0.85, "speed_mult": 1.0, "reward_mult": 1.0, "life_dmg": 1, "bar_y": -46.0, "boss": false},
	"goblin": {"hp_mult": 0.72, "speed_mult": 1.38, "reward_mult": 1.0, "life_dmg": 1, "bar_y": -52.0, "boss": false},
	"orc": {"hp_mult": 1.45, "speed_mult": 0.88, "reward_mult": 1.35, "life_dmg": 1, "bar_y": -58.0, "boss": false},
	"golem": {"hp_mult": 2.4, "speed_mult": 0.65, "reward_mult": 1.8, "life_dmg": 2, "bar_y": -66.0, "boss": false},
	"boss_troll": {"hp_mult": 4.2, "speed_mult": 0.62, "reward_mult": 3.5, "life_dmg": 3, "bar_y": -80.0, "boss": true},
}

@export var enemy_type: String = "goblin"
@export var max_hp: float = 60.0
@export var move_speed: float = 95.0
@export var coin_reward: int = 15
@export var life_damage: int = 1
@export var show_placeholder: bool = true

var current_hp: float = 60.0
var is_boss: bool = false
var _is_finished: bool = false
var _slow_multiplier: float = 1.0
var _slow_timer: float = 0.0
var _walk_time: float = 0.0
var _bar_offset_y: float = -52.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: ProgressBar = $HealthBar


func _ready() -> void:
	add_to_group("enemies")
	rotates = false
	loop = false
	current_hp = max_hp
	_apply_enemy_visual()
	_update_health_bar()
	queue_redraw()


func setup(
	hp: float,
	speed: float,
	reward: int,
	damage_to_lives: int = 1,
	boss: bool = false,
	type_id: String = ""
) -> void:
	if type_id != "" and ENEMY_CONFIGS.has(type_id):
		enemy_type = type_id
		var cfg: Dictionary = ENEMY_CONFIGS[type_id]
		max_hp = hp * float(cfg["hp_mult"])
		move_speed = speed * float(cfg["speed_mult"])
		coin_reward = maxi(1, int(round(float(reward) * float(cfg["reward_mult"]))))
		life_damage = int(cfg["life_dmg"])
		is_boss = bool(cfg["boss"])
		_bar_offset_y = float(cfg["bar_y"])
	else:
		max_hp = hp
		move_speed = speed
		coin_reward = reward
		life_damage = damage_to_lives
		is_boss = boss
		_bar_offset_y = -80.0 if is_boss else -52.0
		if is_boss:
			enemy_type = "boss_troll"

	current_hp = max_hp
	if is_node_ready():
		_apply_enemy_visual()
		_update_health_bar()
		queue_redraw()


func _physics_process(delta: float) -> void:
	if _is_finished:
		return

	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_multiplier = 1.0
			if sprite != null:
				sprite.modulate = Color.WHITE

	var prev_pos: Vector2 = global_position
	var effective_speed: float = move_speed * _slow_multiplier
	progress += effective_speed * delta

	var move_delta: Vector2 = global_position - prev_pos
	if sprite != null:
		if absf(move_delta.x) > 0.1:
			sprite.flip_h = move_delta.x < 0.0
		_walk_time += delta * effective_speed * 0.14
		sprite.position.y = -absf(sin(_walk_time)) * 3.5
		sprite.rotation = sin(_walk_time) * 0.05

	if progress_ratio >= 1.0:
		_is_finished = true
		reached_goal.emit(life_damage)
		queue_free()


func apply_slow(factor: float, duration: float) -> void:
	if _is_finished:
		return
	_slow_multiplier = minf(_slow_multiplier, clampf(factor, 0.2, 1.0))
	_slow_timer = maxf(_slow_timer, duration)
	if sprite != null:
		sprite.modulate = Color(0.65, 0.88, 1.0)


func take_damage(amount: float) -> void:
	if _is_finished:
		return

	current_hp = maxf(0.0, current_hp - amount)
	_update_health_bar()

	if current_hp <= 0.0:
		_is_finished = true
		defeated.emit(coin_reward)
		queue_free()


func is_dead() -> bool:
	return _is_finished


func _apply_enemy_visual() -> void:
	if sprite != null and ENEMY_TEXTURES.has(enemy_type):
		sprite.texture = ENEMY_TEXTURES[enemy_type]
	if health_bar != null:
		var half_w: float = 30.0 if is_boss else 22.0
		health_bar.offset_left = -half_w
		health_bar.offset_right = half_w
		health_bar.offset_top = _bar_offset_y
		health_bar.offset_bottom = _bar_offset_y + 8.0


func _update_health_bar() -> void:
	if health_bar == null:
		return
	health_bar.max_value = max_hp
	health_bar.value = current_hp


func _draw() -> void:
	if not show_placeholder or (sprite != null and sprite.texture != null):
		return

	var radius: float = 18.0 if is_boss else 14.0
	var fill_color: Color = Color(0.68, 0.16, 0.78) if is_boss else Color(0.88, 0.24, 0.24)
	draw_circle(Vector2.ZERO, radius, fill_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color.WHITE, 2.0)
