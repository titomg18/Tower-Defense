extends Area2D

@export var speed: float = 420.0
@export var damage: float = 20.0
@export var max_lifetime: float = 2.0
@export var show_placeholder: bool = true

var projectile_type: String = "arrow"
var skin_id: String = ""
var slow_factor: float = 1.0
var slow_duration: float = 0.0
var splash_radius: float = 0.0
var chain_count: int = 0
var chain_radius: float = 115.0

var target: Node2D = null
var _direction: Vector2 = Vector2.RIGHT
var _elapsed: float = 0.0
var _has_hit: bool = false

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	queue_redraw()


func setup(
	target_node: Node2D,
	projectile_damage: float,
	initial_direction: Vector2 = Vector2.RIGHT,
	p_type: String = "arrow",
	p_speed: float = 420.0,
	p_slow_factor: float = 1.0,
	p_slow_duration: float = 0.0,
	p_splash_radius: float = 0.0,
	p_chain_count: int = 0,
	p_skin_id: String = ""
) -> void:
	target = target_node
	damage = projectile_damage
	projectile_type = p_type
	speed = p_speed
	slow_factor = p_slow_factor
	slow_duration = p_slow_duration
	splash_radius = p_splash_radius
	chain_count = p_chain_count
	skin_id = p_skin_id

	if initial_direction.length_squared() > 0.0001:
		_direction = initial_direction.normalized()
	rotation = _direction.angle()
	if is_node_ready():
		queue_redraw()


func _physics_process(delta: float) -> void:
	if _has_hit:
		return

	_elapsed += delta
	if _elapsed >= max_lifetime:
		queue_free()
		return

	if is_instance_valid(target) and not target.is_queued_for_deletion() and (not target.has_method("is_dead") or not target.is_dead()):
		var to_target: Vector2 = target.global_position - global_position
		var step: float = speed * delta
		if to_target.length() <= maxf(step, 10.0):
			_hit_enemy(target)
			return
		_direction = to_target.normalized()
		rotation = _direction.angle()
		global_position += _direction * step
	else:
		# Jika target utama sudah kalah sebelum proyektil sampai, teruskan arah terakhir sebentar.
		global_position += _direction * speed * delta


func _on_area_entered(area: Area2D) -> void:
	if _has_hit:
		return

	var enemy := area.get_parent()
	if enemy != null and enemy.is_in_group("enemies"):
		if not is_instance_valid(target) or enemy == target:
			_hit_enemy(enemy)


func _hit_enemy(enemy: Node) -> void:
	if _has_hit:
		return
	_has_hit = true

	var hit_pos: Vector2 = (enemy as Node2D).global_position if is_instance_valid(enemy) and enemy is Node2D else global_position

	if splash_radius > 0.0:
		for other in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(other) or not (other is Node2D):
				continue
			if other.has_method("is_dead") and other.is_dead():
				continue
			var dist: float = (other as Node2D).global_position.distance_to(hit_pos)
			if dist <= splash_radius:
				var dmg: float = damage if other == enemy else damage * 0.75
				if other.has_method("take_damage"):
					other.take_damage(dmg)
				if slow_duration > 0.0 and other.has_method("apply_slow"):
					other.apply_slow(slow_factor, slow_duration)
	else:
		if is_instance_valid(enemy):
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage)
			if slow_duration > 0.0 and enemy.has_method("apply_slow"):
				enemy.apply_slow(slow_factor, slow_duration)

		if chain_count > 0:
			var remaining_chains: int = chain_count
			var candidates: Array[Node2D] = []
			for other in get_tree().get_nodes_in_group("enemies"):
				if other == enemy or not is_instance_valid(other) or not (other is Node2D):
					continue
				if other.has_method("is_dead") and other.is_dead():
					continue
				if (other as Node2D).global_position.distance_to(hit_pos) <= chain_radius:
					candidates.append(other as Node2D)
			candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
				return a.global_position.distance_squared_to(hit_pos) < b.global_position.distance_squared_to(hit_pos)
			)
			for c in candidates:
				if remaining_chains <= 0:
					break
				if is_instance_valid(c) and c.has_method("take_damage"):
					c.take_damage(damage * 0.65)
					remaining_chains -= 1

	queue_free()


func _draw() -> void:
	if not show_placeholder or (sprite != null and sprite.texture != null):
		return

	match projectile_type:
		"ice":
			var fill_col := Color(0.45, 0.9, 1.0)
			var edge_col := Color.WHITE
			if skin_id.ends_with("_emas"):
				fill_col = Color(1.0, 0.86, 0.25)
				edge_col = Color(1.0, 0.96, 0.72)
			elif skin_id.ends_with("_elven"):
				fill_col = Color(0.38, 0.92, 0.48)
				edge_col = Color(0.84, 1.0, 0.78)
			elif skin_id.ends_with("_steampunk"):
				fill_col = Color(0.42, 0.78, 1.0)
				edge_col = Color(0.92, 0.72, 0.35)
			elif skin_id.ends_with("_api"):
				fill_col = Color(1.0, 0.45, 0.12)
				edge_col = Color(1.0, 0.88, 0.35)
			var pts := PackedVector2Array([Vector2(9, 0), Vector2(0, 5), Vector2(-9, 0), Vector2(0, -5)])
			draw_colored_polygon(pts, fill_col)
			draw_polyline(PackedVector2Array([Vector2(9, 0), Vector2(0, 5), Vector2(-9, 0), Vector2(0, -5), Vector2(9, 0)]), edge_col, 1.5)
		"cannon":
			if skin_id.ends_with("_api"):
				draw_circle(Vector2.ZERO, 8.0, Color(0.95, 0.36, 0.06, 0.85))
				draw_circle(Vector2.ZERO, 5.5, Color(1.0, 0.78, 0.18))
				draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 16, Color(1.0, 0.9, 0.4), 1.5)
			elif skin_id.ends_with("_emas"):
				draw_circle(Vector2.ZERO, 7.5, Color(0.92, 0.72, 0.16))
				draw_arc(Vector2.ZERO, 7.5, 0.0, TAU, 16, Color(1.0, 0.94, 0.55), 1.6)
				draw_circle(Vector2(-2, -2), 2.2, Color(1.0, 0.96, 0.75))
			elif skin_id.ends_with("_elven"):
				draw_circle(Vector2.ZERO, 7.5, Color(0.24, 0.74, 0.32))
				draw_arc(Vector2.ZERO, 7.5, 0.0, TAU, 16, Color(0.75, 1.0, 0.65), 1.6)
				draw_circle(Vector2(-2, -2), 2.2, Color(0.85, 1.0, 0.75))
			elif skin_id.ends_with("_steampunk"):
				draw_circle(Vector2.ZERO, 7.5, Color(0.58, 0.38, 0.20))
				draw_arc(Vector2.ZERO, 7.5, 0.0, TAU, 16, Color(0.9, 0.72, 0.36), 1.8)
				draw_circle(Vector2(-2, -2), 2.0, Color(0.95, 0.82, 0.55))
			else:
				draw_circle(Vector2.ZERO, 7.0, Color(0.18, 0.2, 0.24))
				draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 16, Color(0.5, 0.55, 0.6), 1.5)
				draw_circle(Vector2(-2, -2), 2.0, Color(0.7, 0.75, 0.8))
		"tesla":
			if skin_id.ends_with("_emas"):
				draw_circle(Vector2.ZERO, 8.0, Color(0.98, 0.78, 0.15, 0.5))
				draw_circle(Vector2.ZERO, 4.8, Color(1.0, 0.95, 0.65))
			elif skin_id.ends_with("_elven"):
				draw_circle(Vector2.ZERO, 8.0, Color(0.25, 0.85, 0.38, 0.5))
				draw_circle(Vector2.ZERO, 4.8, Color(0.75, 1.0, 0.72))
			elif skin_id.ends_with("_steampunk"):
				draw_circle(Vector2.ZERO, 8.0, Color(0.88, 0.52, 0.16, 0.5))
				draw_circle(Vector2.ZERO, 4.8, Color(0.62, 0.92, 1.0))
			elif skin_id.ends_with("_api"):
				draw_circle(Vector2.ZERO, 8.0, Color(1.0, 0.32, 0.08, 0.55))
				draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.82, 0.25))
			else:
				draw_circle(Vector2.ZERO, 7.0, Color(0.25, 0.75, 1.0, 0.45))
				draw_circle(Vector2.ZERO, 4.5, Color(0.75, 0.96, 1.0))
		_:
			# "arrow"
			if skin_id.ends_with("_emas"):
				draw_line(Vector2(-10, 0), Vector2(6, 0), Color(0.98, 0.82, 0.22), 2.8)
				var gold_tip := PackedVector2Array([Vector2(11, 0), Vector2(4, -3.5), Vector2(4, 3.5)])
				draw_colored_polygon(gold_tip, Color(1.0, 0.94, 0.45))
				draw_line(Vector2(-10, 0), Vector2(-13, -3), Color(1.0, 0.9, 0.4), 1.6)
				draw_line(Vector2(-10, 0), Vector2(-13, 3), Color(1.0, 0.9, 0.4), 1.6)
			elif skin_id.ends_with("_elven"):
				draw_line(Vector2(-10, 0), Vector2(6, 0), Color(0.32, 0.82, 0.36), 2.6)
				var elven_tip := PackedVector2Array([Vector2(11, 0), Vector2(4, -3.5), Vector2(4, 3.5)])
				draw_colored_polygon(elven_tip, Color(0.76, 1.0, 0.65))
				draw_line(Vector2(-10, 0), Vector2(-13, -3), Color(0.65, 1.0, 0.55), 1.5)
				draw_line(Vector2(-10, 0), Vector2(-13, 3), Color(0.65, 1.0, 0.55), 1.5)
			elif skin_id.ends_with("_steampunk"):
				draw_line(Vector2(-10, 0), Vector2(6, 0), Color(0.72, 0.45, 0.2), 2.8)
				var sp_tip := PackedVector2Array([Vector2(11, 0), Vector2(4, -3.5), Vector2(4, 3.5)])
				draw_colored_polygon(sp_tip, Color(0.92, 0.82, 0.55))
				draw_line(Vector2(-10, 0), Vector2(-13, -3), Color(0.88, 0.65, 0.32), 1.5)
				draw_line(Vector2(-10, 0), Vector2(-13, 3), Color(0.88, 0.65, 0.32), 1.5)
			elif skin_id.ends_with("_es"):
				draw_line(Vector2(-10, 0), Vector2(6, 0), Color(0.42, 0.86, 1.0), 2.8)
				var ice_tip := PackedVector2Array([Vector2(11, 0), Vector2(4, -3.5), Vector2(4, 3.5)])
				draw_colored_polygon(ice_tip, Color(0.86, 0.98, 1.0))
				draw_line(Vector2(-10, 0), Vector2(-13, -3), Color(0.75, 0.95, 1.0), 1.5)
				draw_line(Vector2(-10, 0), Vector2(-13, 3), Color(0.75, 0.95, 1.0), 1.5)
			else:
				draw_line(Vector2(-9, 0), Vector2(6, 0), Color(0.68, 0.45, 0.22), 2.5)
				var tip := PackedVector2Array([Vector2(10, 0), Vector2(4, -3.5), Vector2(4, 3.5)])
				draw_colored_polygon(tip, Color(0.85, 0.9, 0.95))
				draw_line(Vector2(-9, 0), Vector2(-12, -3), Color.WHITE, 1.5)
				draw_line(Vector2(-9, 0), Vector2(-12, 3), Color.WHITE, 1.5)
