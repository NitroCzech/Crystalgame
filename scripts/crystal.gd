extends Control
## The big tappable crystal, drawn procedurally so no art assets are needed yet.

signal tapped(global_pos: Vector2)

## Base color; facets, outline and glow are derived from it.
var tint := Color("8c6dff"):
	set(value):
		tint = value
		queue_redraw()
## When false the crystal is display-only (e.g. in the geode reveal).
var interactive := true

var _time := 0.0
var _tween: Tween


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP if interactive else MOUSE_FILTER_IGNORE
	resized.connect(func() -> void: pivot_offset = size / 2.0)
	pivot_offset = size / 2.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	# Touches arrive as emulated mouse clicks, so this covers mobile and desktop.
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit(click.global_position)
		_bounce()
		accept_event()


func _bounce() -> void:
	if _tween:
		_tween.kill()
	scale = Vector2(0.9, 0.9)
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.25)


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) * 0.45
	var pulse := 0.5 + 0.5 * sin(_time * 2.0)
	var facet_light := tint.lightened(0.4)
	var facet_mid := tint
	var facet_dark := tint.darkened(0.4)
	var outline_color := tint.lightened(0.75)

	for i in 3:
		draw_circle(c, r * (1.15 - i * 0.08), Color(tint, 0.06 + 0.04 * pulse))

	var top := c + Vector2(0, -r)
	var bottom := c + Vector2(0, r)
	var upper_right := c + Vector2(r * 0.72, -r * 0.38)
	var lower_right := c + Vector2(r * 0.55, r * 0.45)
	var lower_left := c + Vector2(-r * 0.55, r * 0.45)
	var upper_left := c + Vector2(-r * 0.72, -r * 0.38)
	var core := c + Vector2(0, -r * 0.12)

	var facets := [
		[top, upper_right, core, facet_light],
		[top, upper_left, core, facet_light.darkened(0.12)],
		[upper_left, lower_left, core, facet_mid.darkened(0.1)],
		[upper_right, lower_right, core, facet_mid],
		[lower_left, bottom, core, facet_dark],
		[lower_right, bottom, core, facet_dark.lightened(0.1)],
	]
	for f in facets:
		draw_colored_polygon(PackedVector2Array([f[0], f[1], f[2]]), f[3])

	var outline := PackedVector2Array([top, upper_right, lower_right, bottom, lower_left, upper_left, top])
	draw_polyline(outline, outline_color, 3.0, true)

	# A little moving sparkle.
	var sparkle_pos := c + Vector2(-r * 0.25, -r * 0.45) + Vector2(cos(_time), sin(_time * 1.3)) * r * 0.05
	var s := r * (0.05 + 0.03 * pulse)
	draw_colored_polygon(PackedVector2Array([
		sparkle_pos + Vector2(0, -s * 2), sparkle_pos + Vector2(s * 0.4, 0),
		sparkle_pos + Vector2(0, s * 2), sparkle_pos + Vector2(-s * 0.4, 0),
	]), Color(1, 1, 1, 0.8))
	draw_colored_polygon(PackedVector2Array([
		sparkle_pos + Vector2(-s * 2, 0), sparkle_pos + Vector2(0, -s * 0.4),
		sparkle_pos + Vector2(s * 2, 0), sparkle_pos + Vector2(0, s * 0.4),
	]), Color(1, 1, 1, 0.8))
