extends Control
## Main screen: shard counter, the crystal, and the shop. Built in code so the
## layout is easy to tweak without the editor.

const Crystal := preload("res://scripts/crystal.gd")

const BG_COLOR := Color("140c2a")
const PANEL_COLOR := Color("23174a")
const ACCENT := Color("8c6dff")
const TEXT_DIM := Color("b8aee0")
const GOLD := Color("ffd76a")

var _shards_label: Label
var _rate_label: Label
var _crystal: Control
var _tap_button: Button
var _tap_labels: Array[Label] = []
## Generator id -> {button, name_label, info_label, cost_label}
var _generator_rows := {}


func _ready() -> void:
	theme = _make_theme()
	_build_ui()
	Game.offline_income_awarded.connect(_show_offline_popup)
	var report := Game.take_offline_report()
	if report.amount > 0.0:
		_show_offline_popup(report.amount, report.seconds)
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	_shards_label.text = Game.format_number(floorf(Game.shards))
	_rate_label.text = "%s shards / sec" % Game.format_number(Game.get_shards_per_second())

	var tap_cost := Game.get_tap_upgrade_cost()
	_tap_labels[0].text = "Sharper Pickaxe  (Lv %d)" % Game.tap_level
	_tap_labels[1].text = "+%s per tap → +%s" % [
		Game.format_number(Game.get_tap_value()), Game.format_number(Game.get_tap_value() * 2.0)]
	_tap_labels[2].text = Game.format_number(tap_cost)
	_tap_button.disabled = Game.shards < tap_cost

	for def in Game.GENERATORS:
		var row: Dictionary = _generator_rows[def.id]
		var count: int = Game.owned.get(def.id, 0)
		var cost := Game.get_generator_cost(def.id)
		row.name_label.text = "%s  ×%d" % [def.name, count]
		row.info_label.text = "+%s/s each" % Game.format_number(def.rate)
		row.cost_label.text = Game.format_number(cost)
		row.button.disabled = Game.shards < cost


func _on_crystal_tapped(global_pos: Vector2) -> void:
	var value := Game.tap()
	_spawn_floating_text("+" + Game.format_number(value), global_pos)


func _spawn_floating_text(text: String, global_pos: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", ACCENT.darkened(0.4))
	label.add_theme_constant_override("outline_size", 8)
	add_child(label)
	var jitter := Vector2(randf_range(-30, 30), 0)
	label.position = global_pos - global_position - Vector2(30, 40) + jitter
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 140, 0.8) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.2)
	tween.chain().tween_callback(label.queue_free)


# --- UI construction ---------------------------------------------------------

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 56)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	_shards_label = _make_label("0", 72, Color.WHITE)
	_shards_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_shards_label)

	var caption := _make_label("crystal shards", 28, TEXT_DIM)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(caption)

	_rate_label = _make_label("", 26, GOLD)
	_rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_rate_label)

	var crystal_area := CenterContainer.new()
	crystal_area.size_flags_vertical = SIZE_EXPAND_FILL
	crystal_area.size_flags_stretch_ratio = 1.0
	column.add_child(crystal_area)

	_crystal = Crystal.new()
	_crystal.custom_minimum_size = Vector2(380, 380)
	_crystal.tapped.connect(_on_crystal_tapped)
	crystal_area.add_child(_crystal)

	column.add_child(_make_label("Shop", 32, Color.WHITE))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 1.1
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	var shop := VBoxContainer.new()
	shop.size_flags_horizontal = SIZE_EXPAND_FILL
	shop.add_theme_constant_override("separation", 10)
	scroll.add_child(shop)

	var tap_row := _make_shop_row()
	_tap_button = tap_row.button
	_tap_labels = [tap_row.name_label, tap_row.info_label, tap_row.cost_label]
	_tap_button.pressed.connect(Game.buy_tap_upgrade)
	shop.add_child(_tap_button)

	for def in Game.GENERATORS:
		var row := _make_shop_row()
		row.button.pressed.connect(Game.buy_generator.bind(def.id))
		shop.add_child(row.button)
		_generator_rows[def.id] = row


func _make_shop_row() -> Dictionary:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 104)
	button.size_flags_horizontal = SIZE_EXPAND_FILL

	var inner := MarginContainer.new()
	inner.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	inner.mouse_filter = MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("margin_left", 20)
	inner.add_theme_constant_override("margin_right", 20)
	button.add_child(inner)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = MOUSE_FILTER_IGNORE
	inner.add_child(hbox)

	var text_col := VBoxContainer.new()
	text_col.mouse_filter = MOUSE_FILTER_IGNORE
	text_col.size_flags_horizontal = SIZE_EXPAND_FILL
	text_col.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(text_col)

	var name_label := _make_label("", 30, Color.WHITE)
	var info_label := _make_label("", 22, TEXT_DIM)
	text_col.add_child(name_label)
	text_col.add_child(info_label)

	var cost_label := _make_label("", 30, GOLD)
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.size_flags_vertical = SIZE_FILL
	hbox.add_child(cost_label)

	return {"button": button, "name_label": name_label, "info_label": info_label, "cost_label": cost_label}


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 28
	var states := {
		"normal": PANEL_COLOR,
		"hover": PANEL_COLOR.lightened(0.08),
		"pressed": ACCENT.darkened(0.3),
		"disabled": PANEL_COLOR.darkened(0.35),
		"focus": Color(0, 0, 0, 0),
	}
	for state in states:
		var sb := StyleBoxFlat.new()
		sb.bg_color = states[state]
		sb.set_corner_radius_all(18)
		if state == "normal" or state == "hover":
			sb.border_color = ACCENT.darkened(0.2)
			sb.set_border_width_all(2)
		t.set_stylebox(state, "Button", sb)
	var panel := StyleBoxFlat.new()
	panel.bg_color = PANEL_COLOR
	panel.border_color = ACCENT
	panel.set_border_width_all(3)
	panel.set_corner_radius_all(24)
	panel.set_content_margin_all(32)
	t.set_stylebox("panel", "PanelContainer", panel)
	return t


func _show_offline_popup(amount: float, seconds: float) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.mouse_filter = MOUSE_FILTER_STOP
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	panel.add_child(box)

	var title := _make_label("Welcome back!", 44, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var body := _make_label(
			"Your mines kept digging for %s.\nYou earned" % Game.format_duration(seconds), 28, TEXT_DIM)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.custom_minimum_size = Vector2(520, 0)
	box.add_child(body)

	var amount_label := _make_label("+%s shards" % Game.format_number(amount), 52, GOLD)
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(amount_label)

	var collect := Button.new()
	collect.text = "Collect"
	collect.custom_minimum_size = Vector2(0, 88)
	collect.pressed.connect(overlay.queue_free)
	box.add_child(collect)
