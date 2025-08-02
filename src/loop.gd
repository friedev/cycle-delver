class_name Loop extends Node2D

const DRAW_RADIUS := 1024.0
const BORDER_RADIUS := DRAW_RADIUS / 16.0
const MAX_DEPTH := 4
const SLOTS_PER_SIDE := 3

## Counterclockwise (-1) and clockwise (+1.0).
const DIRECTIONS: Array[float] = [-1.0, +1.0]

## Radius of a child loop as a fraction of its parent's radius.
const CHILD_RADIUS := 0.25
## Maximum radius encompassing all descendants as fraction of the parent radius.
## (See math in comment below.)
const DESCENDANT_RADIUS_BOUND := 1.0 / (1.0 / CHILD_RADIUS - 1.0)

## Hue of the color of loops for each depth.
static var hues_by_depth: Array[float]

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

var radius := DRAW_RADIUS
## The position of the loop represented as the angle from the center of its
## parent loop. Undefined for the root loop.
var angle: float
## Which side of the parent this loop is on.
var parent_direction: float

var depth: int

## I don't know the proper term for this, but this is the angle (around the
## center of the PARENT) of the arc spanning from the loop's center to the point
## at which it intersects the parent.
var radial_angle := INF:
	get:
		if radial_angle == INF:
			# Parent radius squared (2R^2)
			var pr2 := 2.0 * pow(get_parent_loop().radius, 2.0)
			# https://www.mathsisfun.com/algebra/trig-solving-sss-triangles.html
			# cos(A) = (b^2 + c^2 - a^2) / 2bc
			# cos(A) = (R^2 + R^2 - r^2) / 2RR
			# A = acos((2R^2 - r^2) / 2R^2)
			radial_angle = acos((pr2 - pow(radius, 2.0)) / pr2)
		return radial_angle

## Also don't know the term for this, but this is the angle (around the center
## of THIS LOOP) spanning from the direction to the center of the parent to the
## point at which this loop intersects the parent.
var intersection_angle := INF:
	get:
		if intersection_angle == INF:
			# https://www.mathsisfun.com/algebra/trig-solving-sss-triangles.html
			# cos(B) = (c^2 + a^2 - b^2) / 2ca
			# cos(B) = (R^2 + r^2 - R^2) / 2Rr
			# B = acos((r^2) / 2Rr)
			intersection_angle = acos(pow(radius, 2.0) / (2.0 * radius * get_parent_loop().radius))
		return intersection_angle

var vertices_ccw: Array[Loop]
var vertices_cw: Array[Loop]

func _ready() -> void:
	if has_parent_loop():
		scale = Vector2.ONE * 0.25
		update_position.call_deferred()
	else:
		generate_children()
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, DRAW_RADIUS, get_fill_color(), true)
	draw_circle(Vector2.ZERO, DRAW_RADIUS, get_border_color(), false, BORDER_RADIUS, true)


func update_position() -> void:
	position = Vector2(DRAW_RADIUS, 0).rotated(angle)


func get_parent_loop() -> Loop:
	return get_parent() as Loop


func has_parent_loop() -> bool:
	return get_parent_loop() != null


func get_hue() -> float:
	if len(hues_by_depth) <= depth:
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


func get_direction_vertices(direction: float) -> Array[Loop]:
	return vertices_ccw if direction <= 0.0 else vertices_cw


## Get the angle from the center of the PARENT to the point at which this loop
## intersects the parent on the side facing `direction` (i.e. the rest of this
## loop lies immediately in the opposite direction around the parent).
func get_parent_angle(direction: float) -> float:
	return angle + signf(direction) * radial_angle


## Get the angle from the center of THIS LOOP to the point at which this loop
## intersects the parent on the side facing `direction` (i.e. the rest of
## this loop lies immediately in the opposite direction around the parent).
func get_intersection_angle(direction: float) -> float:
	return angle + signf(direction) * (PI - intersection_angle)


## Get the angles of all intersections around this loop, including intersections
## with children and intersections with the parent.
func get_intersection_angles() -> Array[float]:
	var angles: Array[float] = []
	for child_loop: Loop in get_children():
		for direction in DIRECTIONS:
			angles.append(child_loop.get_parent_angle(direction))
	if has_parent_loop():
		for direction in DIRECTIONS:
			angles.append(get_intersection_angle(direction))
	return angles


## Get the angle of the next intersection of any kind, starting from
## `from_angle` and increasing/decreasing according to the sign of `direction`.
func get_next_intersection_angle(from_angle: float, direction: float) -> float:
	var next_angle: float
	var min_difference: float = INF
	for to_angle in get_intersection_angles():
		var difference := angle_difference(from_angle, to_angle)
		difference *= signf(direction)
		while difference < 0:
			difference += 2 * PI
		if difference > 0.0 and difference < min_difference:
			next_angle = to_angle
			min_difference = difference
	return next_angle


## Return the loop intersecting with this loop at the given angle.
func get_intersection(at_angle: float) -> Loop:
	for child_loop: Loop in get_children():
		for direction in DIRECTIONS:
			if is_equal_approx(at_angle, child_loop.get_parent_angle(direction)):
				return child_loop
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


func generate_children() -> void:
	generate_vertices(true, true)
	assign_angles()


func generate_vertices(
	passable_forward: bool,
	passable_backward: bool
) -> void:
	var random_direction := DIRECTIONS[randi() % len(DIRECTIONS)]
	var other_passable_forward := randi() % 2 == 0 if passable_forward else false
	var other_passable_backward := randi() % 2 == 0 if passable_backward else false
	# TODO more elegant way of writing this
	if randi() % 2 == 0:
		generate_vertex(random_direction, 3, passable_forward, passable_backward)
		generate_vertex(-random_direction, 3, other_passable_forward, other_passable_backward)
	else:
		generate_vertex(random_direction, 3, passable_forward, other_passable_backward)
		generate_vertex(-random_direction, 3, other_passable_forward, passable_backward)


func generate_vertex(
	direction: float,
	slots: int,
	passable_forward: bool,
	passable_backward: bool
) -> void:
	for i in range(slots):
		var is_child := depth <= randi() % MAX_DEPTH
		# Child
		if is_child:
			append_child(direction).generate_vertices(passable_forward, passable_backward)
		# Nothing (open arc)
		else:
			# TODO handle not passable sections
			pass


func append_child(direction: float) -> Loop:
	var direction_vertices := get_direction_vertices(direction)
	var child := Loop.new()
	direction_vertices.append(child)
	child.radius = radius * CHILD_RADIUS
	child.parent_direction = direction
	child.depth = depth + 1
	add_child(child)
	return child


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
			direction_vertices[angles_assigned].angle = start_angle + signf(direction) * (i + 1) * PI / 4.0
			direction_vertices[angles_assigned].assign_angles()
			angles_assigned += 1
