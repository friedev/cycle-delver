class_name Valve extends Vertex

## Valve radius as a fraction of parent loop radius.
const VALVE_RADIUS := 1.0 / 6.0
const VALVE_DRAW_SCALE := Loop.DRAW_RADIUS / 6.0

const SCENE := preload("res://src/vertices/valve.tscn")

static var triangle_points := PackedVector2Array(
	[Vector2(-0.75, +1.0), Vector2(+1.5, 0.0), Vector2(-0.75, -1.0)]
)
static var rectangle_points := PackedVector2Array(
	[Vector2(-0.75, +1.0), Vector2(+0.75, +1.0), Vector2(+0.75, -1.0), Vector2(-0.75, -1.0)]
)
static var points_scaled := false

@export_group("Internal Nodes")
@export var lock: Node2D
@export var lock_sprite: Sprite2D
@export var lock_label: Label
@export var unlock_particles: GPUParticles2D

## ID of the key that unlocks this valve. Negative means no lock.
var key_id := -1:
	set(value):
		key_id = value
		update_lock()
## Valve can be passed through while moving clockwise.
var passable_cw: bool
## Valve can be passed through while moving counterclockwise.
var passable_ccw: bool


func _ready() -> void:
	# It's not a valve if it can be passed through in both directions
	assert(not passable_cw or not passable_ccw)
	super._ready()
	update_lock()
	var parent_loop := get_parent_loop()
	self_modulate = parent_loop.get_border_color()
	lock_sprite.modulate = parent_loop.get_fill_color()
	lock_label.modulate = parent_loop.get_border_color()
	queue_redraw()


func _draw() -> void:
	if not points_scaled:
		for i in range(len(triangle_points)):
			triangle_points[i] *= VALVE_DRAW_SCALE
		for i in range(len(rectangle_points)):
			rectangle_points[i] *= VALVE_DRAW_SCALE
		points_scaled = true
	# If this valve isn't passable in either direction, it's a wall (rectangle)
	var points := triangle_points if passable_cw or passable_ccw else rectangle_points
	draw_colored_polygon(points, Color.WHITE)


func update_position() -> void:
	super.update_position()
	var inverted := passable_ccw and not passable_cw
	var mult := -1.0 if inverted else 1.0
	rotation = angle + mult * PI * 0.5
	lock.rotation = - rotation


func is_passable(direction: float) -> bool:
	assert(direction != 0.0)
	return passable_ccw if direction < 0.0 else passable_cw


func update_lock() -> void:
	lock.visible = key_id >= 0
	if key_id >= 0 and key_id < len(Key.display_text):
		lock_label.text = str(Key.display_text[key_id])


func unlock() -> void:
	# Emit particles and reparent to this node's parent so they can finish
	# emitting while this node frees itself
	#remove_child(unlock_particles)
	#add_sibling(unlock_particles)
	#unlock_particles.global_position = global_position
	#unlock_particles.modulate = self_modulate
	#unlock_particles.emitting = true
	#get_tree().create_timer(unlock_particles.lifetime).timeout.connect(unlock_particles.queue_free)
	remove_from_parent()
	queue_free()
