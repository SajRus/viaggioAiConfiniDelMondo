class_name World
extends Node3D

signal loaded

enum Phase { IDLE, GENERATING, MESHING, READY }

const LOAD_BUDGET_USEC: int = 12000
const BORDER_THICKNESS: float = 2.0
const BORDER_HEIGHT: float = 256.0
const LAST_FRAME_PRIORITY: int = 100

@export var chunks_per_side: int = 16
@export var chunk_material: Material

var data: WorldData
var manager: ChunkManager

var _mesher: ChunkMesher = ChunkMesher.new(BlockRegistry)
var _generator: TerrainGenerator
var _saved_diffs: BlockDiffLog
var _nodes: Array[ChunkNode] = []
var _phase: Phase = Phase.IDLE
var _next_chunk: int = 0


func _ready() -> void:
	process_priority = LAST_FRAME_PRIORITY


func _process(_delta: float) -> void:
	match _phase:
		Phase.GENERATING:
			_generate_step()
		Phase.MESHING:
			_mesh_step()
		Phase.READY:
			manager.flush()


## Starts generating over the next frames, then emits [signal loaded].
## [param saved_diffs] are the edits of a saved world, reapplied over the terrain.
func start_generation(world_seed: int, saved_diffs: BlockDiffLog = BlockDiffLog.new()) -> void:
	data = WorldData.new(chunks_per_side, chunks_per_side)
	_saved_diffs = saved_diffs
	manager = ChunkManager.new(data, _mesher, _nodes, saved_diffs)
	_generator = TerrainGenerator.new(world_seed)
	_add_border_walls()
	_next_chunk = 0
	_phase = Phase.GENERATING


## Share of the loading work done so far, from 0 to 1.
func load_progress() -> float:
	var chunks: int = chunks_per_side * chunks_per_side
	match _phase:
		Phase.IDLE:
			return 0.0
		Phase.GENERATING:
			return float(_next_chunk) / float(chunks * 2)
		Phase.MESHING:
			return float(chunks + _next_chunk) / float(chunks * 2)
	return 1.0


func is_ready_to_play() -> bool:
	return _phase == Phase.READY


## Returns the feet position above the center of the world.
func spawn_point() -> Vector3:
	var column: int = chunks_per_side * ChunkData.SIZE_X >> 1
	return Vector3(column + 0.5, data.surface_height(column, column) + 1.0, column + 0.5)


func chunk_nodes() -> Array[ChunkNode]:
	return _nodes


func _generate_step() -> void:
	var start: int = Time.get_ticks_usec()
	while _next_chunk < data.chunks.size() and Time.get_ticks_usec() - start < LOAD_BUDGET_USEC:
		var coords: Vector2i = data.coords_of(_next_chunk)
		_generator.fill_chunk(data.chunks[_next_chunk], coords.x, coords.y)
		_next_chunk += 1
	if _next_chunk == data.chunks.size():
		_apply_saved_diffs()
		_next_chunk = 0
		_phase = Phase.MESHING


func _apply_saved_diffs() -> void:
	for chunk_index: int in _saved_diffs.chunk_indices():
		if chunk_index >= data.chunks.size():
			continue
		var blocks: PackedByteArray = data.chunks[chunk_index].blocks
		var entries: Dictionary[int, int] = _saved_diffs.entries_of(chunk_index)
		for block_index: int in entries:
			blocks[block_index] = entries[block_index]


func _mesh_step() -> void:
	var start: int = Time.get_ticks_usec()
	while _next_chunk < data.chunks.size() and Time.get_ticks_usec() - start < LOAD_BUDGET_USEC:
		_add_chunk_node(_next_chunk)
		_next_chunk += 1
	if _next_chunk == data.chunks.size():
		_phase = Phase.READY
		loaded.emit()


func _add_chunk_node(index: int) -> void:
	var node: ChunkNode = ChunkNode.new(chunk_material)
	var coords: Vector2i = data.coords_of(index)
	node.position = Vector3(coords.x * ChunkData.SIZE_X, 0.0, coords.y * ChunkData.SIZE_Z)
	add_child(node)
	node.rebuild(_mesher, data.chunks[index])
	_nodes.append(node)


func _add_border_walls() -> void:
	var span: float = chunks_per_side * ChunkData.SIZE_X
	var outer: float = span + BORDER_THICKNESS * 2.0
	var half_wall: float = BORDER_THICKNESS * 0.5
	var wall_center_y: float = BORDER_HEIGHT * 0.5 - BORDER_THICKNESS
	var middle: float = span * 0.5
	var walls: StaticBody3D = StaticBody3D.new()
	add_child(walls)
	var wall_x: Vector3 = Vector3(BORDER_THICKNESS, BORDER_HEIGHT, outer)
	var wall_z: Vector3 = Vector3(outer, BORDER_HEIGHT, BORDER_THICKNESS)
	_add_wall(walls, Vector3(-half_wall, wall_center_y, middle), wall_x)
	_add_wall(walls, Vector3(span + half_wall, wall_center_y, middle), wall_x)
	_add_wall(walls, Vector3(middle, wall_center_y, -half_wall), wall_z)
	_add_wall(walls, Vector3(middle, wall_center_y, span + half_wall), wall_z)
	_add_wall(walls, Vector3(middle, -half_wall, middle), Vector3(outer, BORDER_THICKNESS, outer))


func _add_wall(walls: StaticBody3D, center: Vector3, size: Vector3) -> void:
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = box
	collision.position = center
	walls.add_child(collision)
