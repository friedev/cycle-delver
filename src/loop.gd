class_name Loop extends Node2D

## Counterclockwise (-1) and clockwise (+1.0).
const DIRECTIONS := [-1.0, +1.0]

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

@export var radius: float:
	set(value):
		assert(value > 0.0)
		radius = value
		queue_redraw()
## The position of the loop represented as the angle from the center of its
## parent loop. Undefined for the root loop.
@export_range(-180.0, 180.0, 0.001, "radians_as_degrees") var angle: float:
	set(value):
		angle = value
		update_position.call_deferred()

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


func _ready() -> void:
	if has_parent_loop():
		update_position.call_deferred()
	else:
		generate_children(4)
	queue_redraw()


func _draw() -> void:
	var border_width := radius / 16.0
	draw_circle(Vector2.ZERO, radius, get_fill_color(), true)
	draw_circle(Vector2.ZERO, radius, get_border_color(), false, border_width)


func update_position() -> void:
	position = Vector2(get_parent_loop().radius, 0).rotated(angle)


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
				if absf(hue - other_hue) < 0.125:
					hue_different = false
					break
		hues_by_depth.append(hue)
	return hues_by_depth[depth]


func get_fill_color() -> Color:
	return Color.from_hsv(get_hue(), 0.125, 0.875)


func get_border_color() -> Color:
	return Color.from_hsv(get_hue(), 0.25, 0.25)


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


func generate_children(max_depth: int) -> void:
	if depth > max_depth:
		return
	var child_count := randi_range(2, 4)
	for i in range(child_count):
		var child := Loop.new()
		child.radius = radius * CHILD_RADIUS
		var valid_angle := false
		# TODO give up after a certain number of tries
		while not valid_angle:
			valid_angle = true
			child.angle = randf() * TAU
			for other_child: Loop in self.get_children():
				if Vector2.RIGHT.rotated(child.angle).distance_squared_to(Vector2.RIGHT.rotated(other_child.angle)) < DESCENDANT_RADIUS_BOUND:
					valid_angle = false
					break
			if has_parent_loop():
				for direction in DIRECTIONS:
					if Vector2.RIGHT.rotated(child.angle).distance_squared_to(Vector2.RIGHT.rotated(get_intersection_angle(direction))) < DESCENDANT_RADIUS_BOUND:
						valid_angle = false
						break
		child.depth = depth + 1
		add_child(child)
		child.generate_children(max_depth)
