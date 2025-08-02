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

## Hue of the color of loops for each depth, OFFSET BY 1. Depth 0 is actually
## used for storing the environment clear color.
static var hues_by_depth: Array[float]


## Get the hue for vertices at this depth.
static func depth_to_hue(depth_arg: int) -> float:
	if len(hues_by_depth) < MAX_DEPTH + 2:
		var hue_count := MAX_DEPTH + 2
		var hue_offset := randf() / hue_count
		for i in range(MAX_DEPTH + 2):
			hues_by_depth.append(hue_offset + float(i) / hue_count)
		hues_by_depth.shuffle()
		RenderingServer.set_default_clear_color(hue_to_fill_color(hues_by_depth[0]))
	return hues_by_depth[depth_arg + 1]


## Get the fill color associated with a hue.
static func hue_to_fill_color(hue: float) -> Color:
	return Color.from_hsv(hue, 0.125, 0.875)


## Get the border color associated with a hue.
static func hue_to_border_color(hue: float) -> Color:
	return Color.from_hsv(hue, 0.25, 0.25)


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
	# Draw upward line from the root loop representing the entrance to the level
	if not has_parent_loop():
		draw_line(Vector2.ZERO, Vector2.UP * DRAW_RADIUS * 10.0, get_border_color(), BORDER_RADIUS, true)
	draw_circle(Vector2.ZERO, DRAW_RADIUS, get_fill_color(), true)
	draw_circle(Vector2.ZERO, DRAW_RADIUS, get_border_color(), false, BORDER_RADIUS, true)


func get_hue() -> float:
	return depth_to_hue(depth)


func get_fill_color() -> Color:
	return hue_to_fill_color(depth_to_hue(depth))


func get_border_color() -> Color:
	return hue_to_border_color(depth_to_hue(depth))


func get_direction_vertices(direction: float) -> Array[Vertex]:
	assert(direction != 0.0)
	return vertices_ccw if direction < 0.0 else vertices_cw


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


## Randomly decides if a child loop should be created instead of a basic vertex,
## based on depth.
func should_add_child() -> bool:
	return depth <= randi() % MAX_DEPTH


## Return a random direction (-1.0 or +1.0).
func get_random_direction() -> float:
	return DIRECTIONS[randi() % len(DIRECTIONS)]


func generate_root() -> void:
	generate_corridor_loop()
	place_entrance()
	place_goal()
	assign_angles()
	Key.generate_display_text()
	get_tree().call_group("keys", "update_label")
	get_tree().call_group("valves", "update_lock")


# TODO make this less crappy
func place_entrance() -> void:
	var entrance: Entrance = Entrance.new()
	vertices_ccw.append(entrance)
	entrance.parent_direction = -1.0
	entrance.angle = PI * -0.5
	add_child(entrance)
	

# TODO make this less crappy
func place_goal() -> void:
	var goal: Goal = Goal.SCENE.instantiate()
	vertices_ccw.append(goal)
	goal.parent_direction = -1.0
	goal.angle = PI * 0.5
	add_child(goal)


func generate_corridor_loop() -> void:
	var random_direction := get_random_direction()
	var choice := randi() % 6
	#   <-+-<
	#  /     \
	# K       L
	#  \     /
	#   \-+-/
	if choice == 0:
		var key_id := Key.new_id()
		generate_valve(random_direction, true)
		generate_key(random_direction, key_id)
		generate_valve(-random_direction, false)
		generate_locked_wall(-random_direction, key_id)
	#  K1-+-L1
	#  /     \
	# ^       V
	#  \     /
	#  L2-+-K2
	elif choice == 1:
		var key_id_1 := Key.new_id()
		var key_id_2 := Key.new_id()
		generate_key(random_direction, key_id_1)
		generate_valve(random_direction, false)
		generate_locked_wall(random_direction, key_id_2)
		generate_locked_wall(-random_direction, key_id_1)
		generate_valve(-random_direction, true)
		generate_key(-random_direction, key_id_2)
	#   <-+-<
	#  /     \
	# K1      L2
	#  \     /
	#  L1-+-K2
	elif choice == 2:
		var key_id_1 := Key.new_id()
		var key_id_2 := Key.new_id()
		generate_valve(random_direction, true)
		generate_key(random_direction, key_id_1)
		generate_locked_wall(random_direction, key_id_1)
		generate_valve(-random_direction, false)
		generate_locked_wall(-random_direction, key_id_2)
		generate_key(-random_direction, key_id_2)
	#   <-+-L2
	#  /     \
	# K1      K2
	#  \     /
	#  L1-+->
	elif choice == 3:
		var key_id_1 := Key.new_id()
		var key_id_2 := Key.new_id()
		generate_valve(random_direction, true)
		generate_key(random_direction, key_id_1)
		generate_locked_wall(random_direction, key_id_1)
		generate_locked_wall(-random_direction, key_id_2)
		generate_key(-random_direction, key_id_2)
		generate_valve(-random_direction, false)
	#   <-+-<
	#  /     \
	# |       |
	#  \     /
	#   \-+-/
	elif choice == 4:
		generate_valve(random_direction, true)
		generate_valve(-random_direction, false)
	#   K-+-L
	#  /     \
	# --      |
	#  \     /
	#   \-+-/
	elif choice == 5:
		var key_id := Key.new_id()
		generate_key(random_direction, key_id)
		#append_wall(random_direction)
		generate_locked_wall(-random_direction, key_id)
	else:
		assert(false)
	fill_with_corridors()


func fill_with_corridors() -> void:
	for direction in DIRECTIONS:
		var direction_vertices := get_direction_vertices(direction)
		for i in range(SLOTS_PER_SIDE - len(direction_vertices)):
			if should_add_child():
				var loop := append_loop(direction)
				loop.generate_corridor_loop()
				direction_vertices.pop_back()
				direction_vertices.insert(randi_range(0, len(direction_vertices)), loop)


## Generate a valve passable in one direction (forward or backward).
func generate_valve(direction: float, forward: bool) -> void:
	# Child acting as a valve
	if should_add_child():
		var child := append_loop(direction)
		for child_direction in DIRECTIONS:
			child.generate_valve(child_direction, forward)
		child.fill_with_corridors()
	# Valve vertex
	else:
		append_valve(direction, forward, not forward)


## Generate a locked valve; it can be passed in one direction, but cannot be
## passed in the other direction until unlocked.
func generate_locked_valve(
	direction: float,
	forward: bool,
	key_id: int
) -> void:
	assert(key_id >= 0)
	# Child acting as a locked valve
	if should_add_child():
		var child := append_loop(direction)
		var choice := randi() % 3
		# Locked valve on both sides
		if choice == 0:
			for child_direction in DIRECTIONS:
				child.generate_locked_valve(child_direction, forward, key_id)
		# Locked valve on one side, normal valve on other side
		elif choice == 1:
			var random_direction := get_random_direction()
			child.generate_locked_valve(random_direction, forward, key_id)
			child.generate_valve(-random_direction, forward)
		# Normal valve on one side, locked wall on other side
		elif choice == 2:
			var random_direction := get_random_direction()
			child.generate_valve(random_direction, forward)
			child.generate_locked_wall(-random_direction, key_id)
	# Locked valve vertex
	else:
		append_valve(direction, forward, not forward, key_id)


## Generate a locked wall; it cannot be passed until unlocked.
func generate_locked_wall(direction: float, key_id: int) -> void:
	assert(key_id >= 0)
	# Child acting as a locked wall
	if should_add_child():
		var child := append_loop(direction)
		# Locked wall on both sides
		for child_direction in DIRECTIONS:
			child.generate_locked_wall(child_direction, key_id)
		child.fill_with_corridors()
	# Locked wall vertex
	else:
		append_wall(direction, key_id)


# Generate a key.
func generate_key(direction: float, key_id: int) -> void:
	# Child containing a key
	if should_add_child():
		var loop := append_loop(direction)
		loop.generate_key(get_random_direction(), key_id)
		loop.fill_with_corridors()
	# Key vertex
	else:
		append_key(direction, key_id)


func append_vertex(direction: float, vertex: Vertex) -> void:
	vertex.parent_direction = direction
	var direction_vertices := get_direction_vertices(direction)
	assert(len(direction_vertices) < SLOTS_PER_SIDE)
	direction_vertices.append(vertex)
	add_child(vertex)


func append_loop(direction: float) -> Loop:
	var loop := Loop.new()
	loop.radius = radius * CHILD_RADIUS
	loop.depth = depth + 1
	append_vertex(direction, loop)
	return loop


func append_valve(direction: float, passable_forward: bool, passable_backward: bool, key_id := -1) -> Valve:
	var valve: Valve = Valve.SCENE.instantiate()
	valve.radius = radius * Valve.VALVE_RADIUS
	valve.passable_ccw = passable_forward if direction < 0.0 else passable_backward
	valve.passable_cw = passable_forward if direction > 0.0 else passable_backward
	valve.key_id = key_id
	append_vertex(direction, valve)
	return valve


func append_wall(direction: float, key_id := -1) -> Valve:
	return append_valve(direction, false, false, key_id)


func append_key(direction: float, key_id: int) -> Key:
	var key: Key = Key.SCENE.instantiate()
	key.key_id = key_id
	append_vertex(direction, key)
	return key


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
