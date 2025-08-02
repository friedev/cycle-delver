class_name Player extends Node2D

signal move_started
signal move_finished

## Singleton instance.
static var instance: Player

## The angle from the center of the player's current loop at which the player
## is currently located.
@export_range(-180.0, 180.0, 0.001, "radians_as_degrees") var angle: float:
	set(value):
		angle = value
		update_position.call_deferred()
## The current loop the player is on, meaning the one on which they could move
## clockwise or counterclockwise.
@export var loop: Loop:
	set(value):
		loop = value
		update_position.call_deferred()
## Sprite shown after reaching the goal.
@export var goal_sprite: Sprite2D
## The vertex that the player is currently at. This can be a child of the
## current loop, parent of the current loop, or another vertex like a valve.
var vertex: Vertex
## Has the player collected the goal item?
var reached_goal: bool:
	set(value):
		reached_goal = value
		goal_sprite.visible = reached_goal

## List of IDs of keys the player has collected.
var collected_keys: Array[int]

# Data for tracking movement animation
var moving: bool
var target_angle: float
var last_direction: float
var velocity: float


func _enter_tree() -> void:
	Player.instance = self


func _ready() -> void:
	update_position.call_deferred()
	queue_redraw()
	update_sprite()
	

func _draw() -> void:
	draw_circle(Vector2.ZERO, Loop.DRAW_RADIUS / 12.0, Color.WHITE, true, -1.0, true)


func _unhandled_input(event: InputEvent) -> void:
	if moving:
		return
	handle_input_event(event)


func handle_input_event(event: InputEvent) -> void:
	assert(not moving)
	var input_direction := Input.get_axis("move_ccw", "move_cw")
	if not is_zero_approx(input_direction):
		move_to_next_vertex(input_direction)
	elif event.is_action_pressed("move_out"):
		if vertex != null and vertex == loop.get_parent_loop():
			move_out()
	elif event.is_action_pressed("move_toward_mouse"):
		var mouse_angle := global_position.angle_to_point(get_global_mouse_position())
		var movement_angles: Array[float] = get_movement_angles()
		var closest_angle_index: int
		var closest_angle_difference := INF
		for i in range(len(movement_angles)):
			var difference := absf(angle_difference(mouse_angle, movement_angles[i]))
			if difference < closest_angle_difference:
				closest_angle_index = i
				closest_angle_difference = difference
		if closest_angle_index == 0:
			move_to_next_vertex(-1.0)
		elif closest_angle_index == 1:
			move_to_next_vertex(+1.0)
		else:
			move_out()


func _process(delta: float) -> void:
	if moving:
		animate_movement(delta)


func move_to_angle(to_angle: float) -> void:
	moving = true
	target_angle = to_angle
	velocity = 0.0
	move_started.emit()


func animate_movement(delta: float) -> void:
	velocity = last_direction * move_toward(absf(velocity), 2.0 * TAU, 2.0 * TAU * delta)
	if absf(angle_difference(angle, target_angle)) < absf(velocity * delta):
		finish_movement()
	else:
		angle += velocity * delta


func finish_movement() -> void:
	moving = false
	angle = target_angle
	var new_vertex := loop.get_vertex(angle)
	if new_vertex is Loop and new_vertex != loop.get_parent_loop():
		vertex = loop
		loop = new_vertex
		angle = loop.get_intersection_angle(-last_direction)
	else:
		vertex = new_vertex
		if vertex is Key:
			var key: Key = vertex
			collected_keys.append(key.key_id)
			key.remove_from_parent()
			SignalBus.key_collected.emit(key)
			vertex = null
		elif vertex is Valve:
			var valve: Valve = vertex
			if valve.key_id in self.collected_keys:
				SignalBus.key_removed.emit(valve.key_id)
				self.collected_keys.erase(valve.key_id)
				valve.remove_from_parent()
				valve.queue_free()
				vertex = null
		elif vertex is Goal:
			var goal: Goal = vertex
			goal.remove_from_parent()
			goal.queue_free()
			reached_goal = true
			vertex = null
	update_sprite()
	move_finished.emit()


## Move in the given direction around the current loop until reaching the next
## intersection (with a child of the current loop or with its parent).
func move_to_next_vertex(direction: float) -> void:
	# Prevent moving against valves, but allow backing away from an impassable
	# valve (`direction == last_direction`)
	if vertex is Valve and not (vertex as Valve).is_passable(direction) and direction == last_direction:
		return

	# Skip over valves that we can move through
	var skip_next_vertex := true
	var next_vertex_angle := angle
	var next_vertex: Vertex
	while skip_next_vertex:
		next_vertex_angle = loop.get_next_vertex_angle(next_vertex_angle, direction)
		next_vertex = loop.get_vertex(next_vertex_angle)
		skip_next_vertex = next_vertex is Valve and (next_vertex as Valve).is_passable(direction)

	last_direction = direction
	move_to_angle(next_vertex_angle)


## If at an intersection with the current loop's parent, move along it until
## reaching the next intersection along the parent in that direction.
func move_out() -> void:
	assert(vertex != null and vertex == loop.get_parent_loop())
	var direction := loop.get_parent_intersection_direction(angle)
	angle = loop.get_parent_angle(direction)
	loop = loop.get_parent()
	move_to_next_vertex(direction)


func update_position() -> void:
	global_position = loop.global_position + Vector2(loop.radius, 0).rotated(angle)


func update_sprite() -> void:
	var new_scale := Vector2.ONE * pow(Loop.CHILD_RADIUS, maxi(0, loop.depth))
	create_tween().tween_property(self, "scale", new_scale, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var hue := loop.get_hue()
	self_modulate = Color.from_hsv(hue, 0.5, 0.5)
	goal_sprite.modulate = Goal.hue_to_color(hue)


## Return the angles representing the directions in which the player can
## currently move.
func get_movement_angles() -> Array[float]:
	var angles: Array[float] = [angle - PI * 0.5, angle + PI * 0.5]
	if vertex == loop.get_parent():
		angles.append(angle)
	return angles
