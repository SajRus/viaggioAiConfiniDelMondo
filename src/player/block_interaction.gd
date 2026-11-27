class_name BlockInteraction
extends Node

const REACH: float = 5.0
const HIGHLIGHT_GROWTH: float = 0.006
const CRACK_GROWTH: float = 0.003
const HOTBAR_KEY_COUNT: int = 8
const TILE_CRACK_FIRST: int = 10

@export var atlas: Texture2D

var hotbar: Hotbar = Hotbar.new()
var combat: Combat = Combat.new()
## Set in survival: blocks come from here and broken blocks go here.
var inventory: Inventory = null
var target: VoxelHit = null

var _data: WorldData = null
var _manager: ChunkManager = null
var _highlight: MeshInstance3D
var _crack: MeshInstance3D
var _crack_material: StandardMaterial3D
var _progress: BreakProgress = BreakProgress.new()

@onready var _player: Player = get_parent()
@onready var _camera: Camera3D = $"../Head/Camera"


func _ready() -> void:
	_build_highlight()
	_build_crack()


func _process(delta: float) -> void:
	update_target()
	if inventory == null:
		return
	combat.update(delta)
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		hold_primary(delta)
	else:
		release_break()


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


## Item of the selected hotbar slot: from the inventory in survival.
func selected_item() -> int:
	if inventory != null:
		return inventory.items[hotbar.selected_index]
	return hotbar.selected_block()


## Creative: breaks the target at once.
func break_target() -> bool:
	update_target()
	return _manager != null and BlockEditor.break_block(_manager, target)


## Survival: one frame of holding the left button. Strikes the aimed boss,
## or works on breaking the targeted block. Returns the damage dealt.
func hold_primary(delta: float) -> int:
	update_target()
	var boss: Boss = aimed_boss()
	if boss == null:
		hold_break(delta)
		return 0
	release_break()
	return combat.swing(boss, selected_item())


## The boss along the view within reach, unless a block stands closer.
func aimed_boss() -> Boss:
	var bosses: Array[Boss] = []
	for node: Node in get_tree().get_nodes_in_group(Boss.GROUP):
		bosses.append(node as Boss)
	var boss: Boss = Combat.aimed_boss(_camera.global_position, -_camera.global_basis.z, bosses)
	if boss == null:
		return null
	var distance: float = Combat.distance_to(_camera.global_position, -_camera.global_basis.z, boss)
	if target != null and target.distance < distance:
		return null
	return boss


## Survival: one frame of holding the button. Breaks the target, and collects
## what it drops, once it has been held long enough.
func hold_break(delta: float) -> bool:
	update_target()
	if _manager == null or target == null:
		release_break()
		return false
	var block: int = _manager.get_block(target.block.x, target.block.y, target.block.z)
	var needed: float = ItemTable.break_seconds(block, selected_item())
	if not _progress.advance(target.block, delta, needed):
		_show_crack()
		return false
	release_break()
	if not BlockEditor.break_block(_manager, target):
		return false
	var drop: int = ItemTable.drop_of(block)
	if drop != ItemTable.NONE:
		inventory.add(drop, 1)
	return true


func release_break() -> void:
	_progress.reset()
	_crack.visible = false


func place_target() -> bool:
	update_target()
	if _manager == null:
		return false
	var item: int = selected_item()
	if not ItemTable.is_block(item):
		return false
	if not BlockEditor.place_block(_manager, target, item, _player.global_position):
		return false
	if inventory != null:
		inventory.take_one(hotbar.selected_index)
	return true


func _handle_mouse_button(button: MouseButton) -> void:
	match button:
		MOUSE_BUTTON_WHEEL_UP:
			hotbar.scroll(-1)
		MOUSE_BUTTON_WHEEL_DOWN:
			hotbar.scroll(1)
		MOUSE_BUTTON_LEFT:
			if inventory == null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				break_target()
		MOUSE_BUTTON_RIGHT:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				place_target()


func _show_crack() -> void:
	var origin: Vector2 = BlockTable.tile_uv_origin(TILE_CRACK_FIRST + _progress.stage())
	_crack_material.uv1_offset = Vector3(origin.x, origin.y, 0.0)
	_crack.position = Vector3(_progress.cell) - Vector3.ONE * CRACK_GROWTH
	_crack.visible = true


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


## A cube drawn over the block being broken, with one crack tile on each face:
## the chunk mesh is not rebuilt until the block goes.
func _build_crack() -> void:
	var vertices: PackedVector3Array = []
	var normals: PackedVector3Array = []
	var uvs: PackedVector2Array = []
	var indices: PackedInt32Array = []
	for face: int in ChunkMesher.FACES:
		var first: int = vertices.size()
		for corner: int in 4:
			vertices.append(ChunkMesher.FACE_CORNERS[face * 4 + corner])
			normals.append(ChunkMesher.FACE_NORMALS[face])
			uvs.append(ChunkMesher.CORNER_UVS[corner])
		indices.append_array([first, first + 1, first + 2, first, first + 2, first + 3])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_crack_material = StandardMaterial3D.new()
	_crack_material.albedo_texture = atlas
	_crack_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_crack_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_crack_material.uv1_scale = Vector3(BlockTable.ATLAS_TILE_UV, BlockTable.ATLAS_TILE_UV, 1.0)
	_crack = MeshInstance3D.new()
	_crack.mesh = mesh
	_crack.material_override = _crack_material
	_crack.scale = Vector3.ONE * (1.0 + CRACK_GROWTH * 2.0)
	_crack.visible = false
	add_child(_crack)


func _corner_position(corner: int) -> Vector3:
	return Vector3(corner & 1, (corner >> 1) & 1, (corner >> 2) & 1)
