class_name HealthView
extends Control

## Health bar above the hotbar. Like every HUD control, it ignores the mouse.

const COLOR_BACK: Color = Color(0.0, 0.0, 0.0, 0.55)
const COLOR_FILL: Color = Color(0.85, 0.15, 0.15, 0.95)

var _fill: ColorRect
var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back: ColorRect = ColorRect.new()
	back.color = COLOR_BACK
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	_fill = ColorRect.new()
	_fill.color = COLOR_FILL
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fill)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_label)


func setup(health: Health) -> void:
	health.changed.connect(_show)
	_show(health.points)


func label_text() -> String:
	return _label.text


func _show(points: int) -> void:
	_fill.anchor_right = float(points) / float(Health.MAX)
	_fill.offset_right = 0.0
	_label.text = "Salute %d/%d" % [points, Health.MAX]
