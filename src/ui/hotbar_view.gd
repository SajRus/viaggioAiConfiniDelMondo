class_name HotbarView
extends HBoxContainer

const SLOT_SIZE: float = 56.0
const ICON_MARGIN: float = 4.0
const COLOR_SELECTED: Color = Color(1.0, 1.0, 1.0, 0.95)
const COLOR_IDLE: Color = Color(0.0, 0.0, 0.0, 0.55)

@export var atlas: Texture2D

var _frames: Array[ColorRect] = []


## Controls here must ignore the mouse: the captured pointer sits inside the HUD.
func setup(hotbar: Hotbar) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for block: int in Hotbar.BLOCKS:
		_add_slot(block)
	hotbar.selection_changed.connect(_show_selection)
	_show_selection(hotbar.selected_index)


func _add_slot(block: int) -> void:
	var frame: ColorRect = ColorRect.new()
	frame.custom_minimum_size = Vector2.ONE * SLOT_SIZE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon: TextureRect = TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = _icon_for(block)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, int(ICON_MARGIN))
	frame.add_child(icon)
	add_child(frame)
	_frames.append(frame)


func _icon_for(block: int) -> AtlasTexture:
	var tile_size: Vector2 = Vector2.ONE * BlockTable.ATLAS_TILE_PIXELS
	var origin: Vector2 = BlockTable.tile_uv_origin(BlockRegistry.tile_side[block]) * atlas.get_size()
	var icon: AtlasTexture = AtlasTexture.new()
	icon.atlas = atlas
	icon.region = Rect2(origin, tile_size)
	return icon


func _show_selection(index: int) -> void:
	for slot: int in _frames.size():
		_frames[slot].color = COLOR_SELECTED if slot == index else COLOR_IDLE
