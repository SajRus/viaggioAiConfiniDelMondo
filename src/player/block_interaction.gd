class_name BlockInteraction
extends Node

const REACH: float = 5.0
const HIGHLIGHT_GROWTH: float = 0.006
const HOTBAR_KEY_COUNT: int = 8

var hotbar: Hotbar = Hotbar.new()
var target: VoxelHit = null

var _data: WorldData = null
var _manager: ChunkManager = null
var _highlight: MeshInstance3D

@onready var _player: Player = get_parent()
@onready var _camera: Camera3D = $"../Head/Camera"


func _ready() -> void:
	_build_highlight()


func _process(_delta: float) -> void:
	update_target()


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo:
		var slot: int = key.physical_keycode - KEY_1
		if slot >= 0 and slot < HOTBAR_KEY_COUNT:
			hotbar.select(slot)
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed:
		_handle_mouse_button(button.button_index)


func setup(data: WorldData, manager: ChunkManager) -> void:
	_data = data
	_manager = manager


func update_target() -> void:
	if _data == null:
		return
	target = VoxelRaycast.cast_ray(
		_data, BlockRegistry, _camera.global_position, -_camera.global_basis.z, REACH
	)
	_highlight.visible = target != null
	if target != null:
		_highlight.position = Vector3(target.block) - Vector3.ONE * HIGHLIGHT_GROWTH


func break_target() -> bool:
	update_target()
	return _manager != null and BlockEditor.break_block(_manager, target)


func place_target() -> bool:
	update_target()
	if _manager == null:
		return false
	return BlockEditor.place_block(_manager, target, hotbar.selected_block(), _player.global_position)


func _handle_mouse_button(button: MouseButton) -> void:
	match button:
		MOUSE_BUTTON_WHEEL_UP:
			hotbar.scroll(-1)
		MOUSE_BUTTON_WHEEL_DOWN:
			hotbar.scroll(1)
		MOUSE_BUTTON_LEFT:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				break_target()
		MOUSE_BUTTON_RIGHT:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				place_target()


func _build_highlight() -> void:
	var lines: PackedVector3Array = []
	for corner: int in 8:
		for bit: int in 3:
			if (corner >> bit) & 1 == 0:
				lines.append(_corner_position(corner))
				lines.append(_corner_position(corner | (1 << bit)))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = lines
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color.BLACK
	_highlight = MeshInstance3D.new()
	_highlight.mesh = mesh
	_highlight.material_override = material
	_highlight.scale = Vector3.ONE * (1.0 + HIGHLIGHT_GROWTH * 2.0)
	_highlight.visible = false
	add_child(_highlight)


func _corner_position(corner: int) -> Vector3:
	return Vector3(corner & 1, (corner >> 1) & 1, (corner >> 2) & 1)
