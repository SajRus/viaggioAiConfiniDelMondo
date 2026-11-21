class_name HotbarView
extends HBoxContainer

const SLOT_SIZE: float = 56.0
const ICON_MARGIN: float = 4.0
const COLOR_SELECTED: Color = Color(1.0, 1.0, 1.0, 0.95)
const COLOR_IDLE: Color = Color(0.0, 0.0, 0.0, 0.55)

@export var atlas: Texture2D

var _frames: Array[ColorRect] = []
var _icons: Array[TextureRect] = []
var _counts: Array[Label] = []
var _inventory: Inventory = null


## Controls here must ignore the mouse: the captured pointer sits inside the HUD.
## With an [param inventory] the slots show its first 8 stacks, otherwise the
## fixed creative blocks.
func setup(hotbar: Hotbar, inventory: Inventory = null) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inventory = inventory
	for slot: int in Hotbar.BLOCKS.size():
		_add_slot()
	if _inventory == null:
		for slot: int in Hotbar.BLOCKS.size():
			_icons[slot].texture = ItemIcons.icon(atlas, Hotbar.BLOCKS[slot])
	else:
		_inventory.changed.connect(_show_inventory)
		_show_inventory()
	hotbar.selection_changed.connect(_show_selection)
	_show_selection(hotbar.selected_index)


func count_text(slot: int) -> String:
	return _counts[slot].text


func _add_slot() -> void:
	var frame: ColorRect = ColorRect.new()
	frame.custom_minimum_size = Vector2.ONE * SLOT_SIZE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon: TextureRect = TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, int(ICON_MARGIN))
	frame.add_child(icon)
	var count: Label = Label.new()
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count.add_theme_constant_override("outline_size", 4)
	count.add_theme_color_override("font_outline_color", Color.BLACK)
	count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, int(ICON_MARGIN))
	frame.add_child(count)
	add_child(frame)
	_frames.append(frame)
	_icons.append(icon)
	_counts.append(count)


func _show_inventory() -> void:
	for slot: int in _frames.size():
		var item: int = _inventory.items[slot]
		var count: int = _inventory.counts[slot]
		_icons[slot].texture = null if item == ItemTable.NONE else ItemIcons.icon(atlas, item)
		_counts[slot].text = str(count) if count > 1 else ""


func _show_selection(index: int) -> void:
	for slot: int in _frames.size():
		_frames[slot].color = COLOR_SELECTED if slot == index else COLOR_IDLE
