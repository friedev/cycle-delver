class_name Valve extends Vertex

## Valve radius as a fraction of parent loop radius.
const VALVE_RADIUS := 1.0 / 32.0
const VALVE_DRAW_SCALE := Loop.DRAW_RADIUS / 8.0

static var triangle_points := PackedVector2Array(
	[Vector2(-1.0, +1.0), Vector2(+1.0, 0.0), Vector2(-1.0, -1.0)]
)
static var rectangle_points := PackedVector2Array(
	[Vector2(-1.0, +1.0), Vector2(+1.0, +1.0), Vector2(+1.0, -1.0), Vector2(-1.0, -1.0)]
)
static var points_scaled := false

## Valve can be passed through while moving clockwise.
var passable_cw: bool
## Valve can be passed through while moving counterclockwise.
var passable_ccw: bool


func _ready() -> void:
	# It's not a valve if it can be passed through in both directions
	assert(not passable_cw or not passable_ccw)
	super._ready()
	modulate = get_parent_loop().get_border_color()
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


func is_passable(direction: float) -> bool:
	assert(direction != 0.0)
	return passable_ccw if direction < 0.0 else passable_cw
