class_name Loop extends Vertex

const DRAW_RADIUS := 1024.0
const BORDER_RADIUS := DRAW_RADIUS / 16.0
const MAX_DEPTH := 4
const SLOTS_PER_SIDE := 3

## Counterclockwise (-1) and clockwise (+1.0).
const DIRECTIONS: Array[float] = [-1.0, +1.0]

## Radius of a child loop as a fraction of its parent's radius.
const CHILD_RADIUS := 1.0 / 4.0
## Maximum radius encompassing all descendants as fraction of the parent radius.
## (See math in comment below.)
const DESCENDANT_RADIUS_BOUND := 1.0 / (1.0 / CHILD_RADIUS - 1.0)

# If the maximum radius of all children is expressed as 1/R, where R is the
# parent radius, the total radius of an infinite number of descendants of that
# child will not exceed 1/(R - 1). In other words, this is the minimum amount of
# separation between child loops that ensures their descendants will never
# intersect. For instance, the radius of all descendants of children each with
# radius 1/4 is bounded by 1/3.
# 
# You can use this Python code to see how the value asymptotically converges:
#
# >>> total_radius = 0.0
# >>> current_radius = 1.0
# >>> mult = 0.25
# >>> for i in range(5):
# ...     current_radius *= mult
# ...     total_radius += current_radius
# ...     print(total_radius)
# ...
# 0.25
# 0.3125
# 0.328125
# 0.33203125
# 0.3330078125

## Hue of the color of loops for each depth.
static var hues_by_depth: Array[float]

var depth: int

var vertices_ccw: Array[Vertex]
var vertices_cw: Array[Vertex]

func _ready() -> void:
	if has_parent_loop():
		super._ready()
		scale = Vector2.ONE * 0.25
	else:
		radius = DRAW_RADIUS
		generate_root()
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, DRAW_RADIUS, get_fill_color(), true)
	draw_circle(Vector2.ZERO, DRAW_RADIUS, get_border_color(), false, BORDER_RADIUS, true)


func get_hue() -> float:
	while len(hues_by_depth) <= depth:
		var hue: float
		# Hue is sufficiently different from any other hue
		var hue_different := false
		while not hue_different:
			hue = randf()
			hue_different = true
			for other_hue in hues_by_depth:
				if absf(hue - other_hue) < 0.1:
					hue_different = false
					break
		hues_by_depth.append(hue)
	return hues_by_depth[depth]


func get_fill_color() -> Color:
	return Color.from_hsv(get_hue(), 0.125, 0.875)


func get_border_color() -> Color:
	return Color.from_hsv(get_hue(), 0.25, 0.25)


func get_direction_vertices(direction: float) -> Array[Vertex]:
	return vertices_ccw if direction <= 0.0 else vertices_cw


## Get the angles of all vertices around this loop, including intersections with
## children, intersections with the parent, and other vertices.
func get_vertex_angles() -> Array[float]:
	var angles: Array[float] = []
	for direction in DIRECTIONS:
		for vertex in get_direction_vertices(direction):
			for child_direction in DIRECTIONS:
				angles.append(vertex.get_parent_angle(child_direction))
				# Don't append duplicate angles if this is a point vertex
				if vertex.radius == 0.0:
					break
	if has_parent_loop():
		for direction in DIRECTIONS:
			angles.append(get_intersection_angle(direction))
	return angles


## Get the angle of the next vertex of any kind, starting from `from_angle` and
## increasing/decreasing according to the sign of `direction`.
func get_next_vertex_angle(from_angle: float, direction: float) -> float:
	var next_angle: float
	var min_difference: float = INF
	for to_angle in get_vertex_angles():
		var difference := angle_difference(from_angle, to_angle)
		difference *= signf(direction)
		while difference < 0:
			difference += 2 * PI
		if difference > 0.0 and difference < min_difference:
			next_angle = to_angle
			min_difference = difference
	return next_angle


## Return the vertex (child loop intersection, parent loop intersection, or
## other vertex) at the given angle.
func get_vertex(at_angle: float) -> Vertex:
	for direction in DIRECTIONS:
		for vertex in get_direction_vertices(direction):
			for child_direction in DIRECTIONS:
				# TODO might also be useful to check if at_angle lies WITHIN
				# the vertex, to support the lower accuracy of real-time movement
				if is_equal_approx(at_angle, vertex.get_parent_angle(child_direction)):
					return vertex
	if has_parent_loop():
		for direction in DIRECTIONS:
			if is_equal_approx(at_angle, get_intersection_angle(direction)):
				return get_parent_loop()
	return null


## Get the direction around the parent that the player would travel if moving
## outward from the current intersection with the parent. If there is no
## intersection with the parent here, return NAN.
func get_parent_intersection_direction(at_angle: float) -> float:
	for direction in DIRECTIONS:
		if is_equal_approx(at_angle, get_intersection_angle(direction)):
			return direction
	assert(false)
	return NAN


func generate_root() -> void:
	generate_vertices(true, true, true)
	assign_angles()


func generate_vertices(
	passable_forward: bool,
	passable_backward: bool,
	force_cycle := false
) -> void:
	var random_direction := DIRECTIONS[randi() % len(DIRECTIONS)]
	# For now, don't allow dead ends (less fun to have to backtrack)
	assert(passable_forward or passable_backward)
	# If this loop is overall passable in both directions, add a chance of
	# making one side only passable forward and/or the other only passable
	# backward
	if passable_forward and passable_backward:
		var other_passable_forward := not force_cycle and randf() < 0.25
		var other_passable_backward := not force_cycle and randf() < 0.25
		generate_vertex(random_direction, 3, true, other_passable_backward)
		generate_vertex(-random_direction, 3, other_passable_forward, true)
	# If this loop is only passable in one direction, leave it that way
	else:
		generate_vertex(random_direction, 3, passable_forward, passable_backward)
		generate_vertex(-random_direction, 3, passable_forward, passable_backward)


func generate_vertex(
	direction: float,
	slots: int,
	passable_forward: bool,
	passable_backward: bool
) -> void:
	var valve_count := 0 if passable_forward and passable_backward else randi_range(1, slots)
	var valves_generated := 0
	for i in range(slots):
		var is_child := depth <= randi() % MAX_DEPTH
		var is_valve := randi() % slots < valve_count - valves_generated
		if is_valve:
			valves_generated += 1
		# Child
		if is_child:
			append_child(direction).generate_vertices(
				passable_forward or not is_valve,
				passable_backward or not is_valve
			)
		else:
			# Valve (or wall)
			if is_valve:
				append_valve(direction, passable_forward, passable_backward)
			# Nothing (open arc)
			else:
				pass


func append_child(direction: float) -> Loop:
	var direction_vertices := get_direction_vertices(direction)
	var child := Loop.new()
	child.radius = radius * CHILD_RADIUS
	child.parent_direction = direction
	child.depth = depth + 1
	direction_vertices.append(child)
	add_child(child)
	return child


func append_valve(direction: float, passable_forward: bool, passable_backward: bool) -> Valve:
	var direction_vertices := get_direction_vertices(direction)
	var valve := Valve.new()
	valve.radius = radius * Valve.VALVE_RADIUS
	valve.passable_ccw = passable_forward if direction < 0.0 else passable_backward
	valve.passable_cw = passable_forward if direction > 0.0 else passable_backward
	direction_vertices.append(valve)
	add_child(valve)
	return valve


func assign_angles() -> void:
	var start_angle := (
		angle - signf(parent_direction) * PI * 0.5
		if has_parent_loop()
		else -PI * 0.5
	)
	for direction in DIRECTIONS:
		var direction_vertices := get_direction_vertices(direction)
		var angles_assigned := 0
		for i in range(SLOTS_PER_SIDE):
			if angles_assigned == len(direction_vertices):
				break
			var spare_slots := SLOTS_PER_SIDE - len(direction_vertices) - i
			if randi() % SLOTS_PER_SIDE < spare_slots:
				continue
			var vertex := direction_vertices[angles_assigned]
			vertex.angle = start_angle + signf(direction) * (i + 1) * PI / 4.0
			if vertex is Loop:
				(vertex as Loop).assign_angles()
			angles_assigned += 1
