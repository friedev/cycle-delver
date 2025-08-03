class_name Vertex extends Node2D

## The radius of this vertex itself.
var radius: float
## The position of this vertex represented as the angle from the center of its
## parent loop. Undefined for the root loop.
var angle: float:
	set(value):
		angle = value
		update_position()
## Which side of the parent loop this vertex is on.
var parent_direction: float

## I don't know the proper term for this, but this is the angle (around the
## center of the PARENT) of the arc spanning from the loop's center to the point
## at which it intersects the parent.
var radial_angle := INF:
	get:
		if radial_angle == INF:
			if radius == 0.0:
				radial_angle = 0.0
			else:
				# Parent radius squared (2R^2)
				var pr2 := 2.0 * pow(get_parent_loop().radius, 2.0)
				# https://www.mathsisfun.com/algebra/trig-solving-sss-triangles.html
				# cos(A) = (b^2 + c^2 - a^2) / 2bc
				# cos(A) = (R^2 + R^2 - r^2) / 2RR
				# A = acos((2R^2 - r^2) / 2R^2)
				radial_angle = acos((pr2 - pow(radius, 2.0)) / pr2)
		return radial_angle


## I don't know the term for this, but this is the angle (around the center of
## THIS LOOP) spanning from the direction to the center of the parent to the
## point at which this loop intersects the parent.
var intersection_angle := INF:
	get:
		if intersection_angle == INF:
			if radius == 0.0:
				intersection_angle = 0.0
			else:
				# https://www.mathsisfun.com/algebra/trig-solving-sss-triangles.html
				# cos(B) = (c^2 + a^2 - b^2) / 2ca
				# cos(B) = (R^2 + r^2 - R^2) / 2Rr
				# B = acos((r^2) / 2Rr)
				intersection_angle = acos(pow(radius, 2.0) / (2.0 * radius * get_parent_loop().radius))
		return intersection_angle


func _ready() -> void:
	update_position()


func update_position() -> void:
	position = Vector2(Loop.DRAW_RADIUS, 0).rotated(angle)


func get_parent_loop() -> Loop:
	return get_parent() as Loop


func has_parent_loop() -> bool:
	return get_parent_loop() != null


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


## Remove this vertex from its parent's array of vertices, and remove it as a
## child.
func remove_from_parent() -> void:
	get_parent_loop().get_direction_vertices(parent_direction).erase(self)
	get_parent().remove_child(self)