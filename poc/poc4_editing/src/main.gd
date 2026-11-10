extends Node3D

enum Phase { GENERATING, MESHING, RUNNING }
enum EditClass { INTERIOR, BORDER, CORNER, BUSIEST_CORNER }

const EDIT_BENCH_ARGUMENT: String = "--edit-bench"
const EDIT_SOAK_ARGUMENT: String = "--edit-soak"
const SOAK_EDITS_PREFIX: String = "--soak-edits="
const SOAK_SEED_PREFIX: String = "--soak-seed="
const DEFAULT_SOAK_EDITS: int = 1000
const WORLD_SEED: int = 1234
const COURSE_SEED: int = 99
const CHUNKS_PER_SIDE_BITS: int = 4
const CHUNKS_PER_SIDE: int = 1 << CHUNKS_PER_SIDE_BITS
const LOAD_BUDGET_USEC: int = 12000
const SPAWN_COLUMN: int = 128
const REACH: float = 5.0
const PLACED_BLOCK: int = BlockTable.PLANKS
const HIGHLIGHT_GROWTH: float = 0.006
const BENCH_SETTLE_FRAMES: int = 90
const BENCH_SAMPLES_PER_CLASS: int = 60
const BENCH_CLASS_LABELS: PackedStringArray = ["interno", "bordo", "angolo", "angolo, chunk più pieno"]

@export var _material: Material

var _table: BlockTable = BlockTable.new()
var _mesher: ChunkMesher = ChunkMesher.new(_table)
var _generator: TerrainGenerator = TerrainGenerator.new(WORLD_SEED)
var _world: WorldData = WorldData.new(CHUNKS_PER_SIDE, CHUNKS_PER_SIDE)
var _nodes: Array[ChunkNode] = []
var _manager: ChunkManager = ChunkManager.new(_world, _mesher, _nodes)
var _phase: Phase = Phase.GENERATING
var _next_chunk: int = 0
var _load_start_usec: int = 0
var _load_total_usec: int = 0
var _last_flush_usec: int = 0
var _last_flush_chunks: int = 0
var _target: VoxelHit = null
var _highlight: MeshInstance3D
var _edit_soak: bool = false
var _soak_edits: int = DEFAULT_SOAK_EDITS
var _soak_seed: int = 1
var _edit_bench: bool = false
var _bench_settle_left: int = BENCH_SETTLE_FRAMES
var _bench_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _bench_class: int = EditClass.INTERIOR
var _bench_samples: Array[PackedInt64Array] = []
var _bench_chunks_rebuilt: PackedInt32Array = PackedInt32Array()
var _bench_restore_position: Vector3i = Vector3i(-1, -1, -1)
var _bench_restore_id: int = BlockTable.AIR
var _bench_busiest_chunk: int = 0

@onready var _chunk_root: Node3D = $Chunks
@onready var _player: Player = $Player
@onready var _camera: Camera3D = $Player/Head/Camera
@onready var _stats: Label = $Hud/Stats


func _ready() -> void:
	_parse_arguments()
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_player.human_controlled = not _edit_soak and not _edit_bench
	_build_highlight()
	_load_start_usec = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	match _phase:
		Phase.GENERATING:
			_generate_step()
		Phase.MESHING:
			_mesh_step()
		Phase.RUNNING:
			if _edit_bench:
				_edit_bench_step()
			_flush_edits()
			_update_target()
	_update_stats()


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and key.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif _phase == Phase.RUNNING:
		_apply_click(button.button_index)


func _apply_click(button: MouseButton) -> void:
	var hit: VoxelHit = _cast_from_camera()
	if button == MOUSE_BUTTON_LEFT:
		BlockEditor.break_block(_manager, hit)
	elif button == MOUSE_BUTTON_RIGHT:
		BlockEditor.place_block(_manager, hit, PLACED_BLOCK, _player.global_position)


func _parse_arguments() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument == EDIT_SOAK_ARGUMENT:
			_edit_soak = true
		elif argument == EDIT_BENCH_ARGUMENT:
			_edit_bench = true
		elif argument.begins_with(SOAK_EDITS_PREFIX):
			_soak_edits = argument.trim_prefix(SOAK_EDITS_PREFIX).to_int()
		elif argument.begins_with(SOAK_SEED_PREFIX):
			_soak_seed = argument.trim_prefix(SOAK_SEED_PREFIX).to_int()


func _build_highlight() -> void:
	var corners: PackedVector3Array = []
	for index: int in 8:
		corners.append(Vector3(index & 1, (index >> 1) & 1, (index >> 2) & 1))
	var lines: PackedVector3Array = []
	for index: int in 8:
		for bit: int in 3:
			if (index >> bit) & 1 == 0:
				lines.append(corners[index])
				lines.append(corners[index | (1 << bit)])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = lines
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	_highlight = MeshInstance3D.new()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color.BLACK
	_highlight.mesh = mesh
	_highlight.material_override = material
	_highlight.scale = Vector3.ONE * (1.0 + HIGHLIGHT_GROWTH * 2.0)
	_highlight.visible = false
	add_child(_highlight)


func _generate_step() -> void:
	var start: int = Time.get_ticks_usec()
	var now: int = start
	while _next_chunk < _world.chunks.size() and now - start < LOAD_BUDGET_USEC:
		var chunk_z: int = _next_chunk >> CHUNKS_PER_SIDE_BITS
		var chunk_x: int = _next_chunk & (CHUNKS_PER_SIDE - 1)
		_generator.fill_chunk(_world.chunks[_next_chunk], chunk_x, chunk_z)
		_next_chunk += 1
		now = Time.get_ticks_usec()
	if _next_chunk == _world.chunks.size():
		ObstacleCourse.add_to(_world, COURSE_SEED)
		_next_chunk = 0
		_phase = Phase.MESHING


func _mesh_step() -> void:
	var start: int = Time.get_ticks_usec()
	var now: int = start
	while _next_chunk < _world.chunks.size() and now - start < LOAD_BUDGET_USEC:
		_add_chunk_node(_next_chunk)
		_next_chunk += 1
		now = Time.get_ticks_usec()
	if _next_chunk == _world.chunks.size():
		_load_total_usec = Time.get_ticks_usec() - _load_start_usec
		_start_playing()


func _add_chunk_node(chunk_index: int) -> void:
	var node: ChunkNode = ChunkNode.new(_material)
	var chunk_z: int = chunk_index >> CHUNKS_PER_SIDE_BITS
	var chunk_x: int = chunk_index & (CHUNKS_PER_SIDE - 1)
	node.position = Vector3(chunk_x * ChunkData.SIZE_X, 0.0, chunk_z * ChunkData.SIZE_Z)
	_chunk_root.add_child(node)
	node.rebuild(_mesher, _world.chunks[chunk_index])
	_nodes.append(node)


func _start_playing() -> void:
	var spawn_y: int = _world.surface_height(SPAWN_COLUMN, SPAWN_COLUMN) + 2
	_player.global_position = Vector3(SPAWN_COLUMN + 0.5, spawn_y, SPAWN_COLUMN + 0.5)
	_player.process_mode = Node.PROCESS_MODE_INHERIT
	_phase = Phase.RUNNING
	if _edit_soak:
		_run_edit_soak()
	elif _edit_bench:
		_prepare_edit_bench()


func _flush_edits() -> void:
	var start: int = Time.get_ticks_usec()
	var rebuilt: PackedInt32Array = _manager.flush()
	if not rebuilt.is_empty():
		_last_flush_usec = Time.get_ticks_usec() - start
		_last_flush_chunks = rebuilt.size()
		_bench_chunks_rebuilt = rebuilt


func _cast_from_camera() -> VoxelHit:
	var origin: Vector3 = _camera.global_position
	return VoxelRaycast.cast_ray(_world, _table, origin, -_camera.global_basis.z, REACH)


func _update_target() -> void:
	_target = _cast_from_camera()
	_highlight.visible = _target != null
	if _target != null:
		_highlight.position = Vector3(_target.block) - Vector3.ONE * HIGHLIGHT_GROWTH


func _update_stats() -> void:
	if _phase != Phase.RUNNING:
		_stats.text = "Generazione del mondo... chunk %d/%d" % [_next_chunk, _world.chunks.size()]
		return
	_stats.text = "%d FPS | ultima modifica: %d chunk in %.2f ms\nClic per il mouse, poi sinistro rompe, destro piazza, WASD, Spazio salta, Esc libera il mouse" % [
		Engine.get_frames_per_second(), _last_flush_chunks, _last_flush_usec * 0.001,
	]


func _run_edit_soak() -> void:
	var mismatches: int = EditSoak.run(_world, _manager, _mesher, _nodes, _soak_edits, _soak_seed)
	var built_faces: int = 0
	for node: ChunkNode in _nodes:
		built_faces += node.face_count
	var expected_faces: int = VoxelAudit.expected_face_count(_world, _table)
	print("Audit: %d modifiche | chunk disallineati %d | facce costruite %d, attese %d" % [
		_soak_edits, mismatches, built_faces, expected_faces,
	])
	get_tree().quit(1 if mismatches > 0 or built_faces != expected_faces else 0)


func _prepare_edit_bench() -> void:
	_bench_rng.seed = 5
	for _class: int in BENCH_CLASS_LABELS.size():
		_bench_samples.append(PackedInt64Array())
	var busiest_faces: int = -1
	for chunk_z: int in range(1, CHUNKS_PER_SIDE - 1):
		for chunk_x: int in range(1, CHUNKS_PER_SIDE - 1):
			var index: int = chunk_x + (chunk_z << CHUNKS_PER_SIDE_BITS)
			if _nodes[index].face_count > busiest_faces:
				busiest_faces = _nodes[index].face_count
				_bench_busiest_chunk = index
	print("Modifica di un blocco, %d campioni per classe, debug build: %s" % [
		BENCH_SAMPLES_PER_CLASS, OS.is_debug_build(),
	])


func _edit_bench_step() -> void:
	if _bench_settle_left > 0:
		_bench_settle_left -= 1
		return
	if _last_flush_usec > 0:
		_bench_samples[_bench_class].append(_last_flush_usec)
		_last_flush_usec = 0
		if _bench_samples[_bench_class].size() == BENCH_SAMPLES_PER_CLASS:
			_print_bench_class()
			_bench_class += 1
			if _bench_class == BENCH_CLASS_LABELS.size():
				get_tree().quit()
				return
	if _bench_restore_position.y >= 0:
		var old: Vector3i = _bench_restore_position
		_manager.set_block(old.x, old.y, old.z, _bench_restore_id)
		_bench_restore_position = Vector3i(-1, -1, -1)
		return
	var column: Vector2i = _bench_column()
	var y: int = _world.surface_height(column.x, column.y)
	_bench_restore_position = Vector3i(column.x, y, column.y)
	_bench_restore_id = _world.get_block_world(column.x, y, column.y)
	_manager.set_block(column.x, y, column.y, BlockTable.AIR)


func _bench_column() -> Vector2i:
	var chunk_x: int = _bench_rng.randi_range(1, CHUNKS_PER_SIDE - 2)
	var chunk_z: int = _bench_rng.randi_range(1, CHUNKS_PER_SIDE - 2)
	var local_x: int = _bench_rng.randi_range(1, WorldData.CHUNK_MASK - 1)
	var local_z: int = _bench_rng.randi_range(1, WorldData.CHUNK_MASK - 1)
	match _bench_class:
		EditClass.BORDER:
			local_x = 0
		EditClass.CORNER:
			local_x = 0
			local_z = 0
		EditClass.BUSIEST_CORNER:
			chunk_x = _bench_busiest_chunk & (CHUNKS_PER_SIDE - 1)
			chunk_z = _bench_busiest_chunk >> CHUNKS_PER_SIDE_BITS
			local_x = 0
			local_z = 0
	return Vector2i((chunk_x << WorldData.CHUNK_BITS) + local_x, (chunk_z << WorldData.CHUNK_BITS) + local_z)


func _print_bench_class() -> void:
	var samples: PackedInt64Array = _bench_samples[_bench_class]
	samples.sort()
	var count: int = samples.size()
	print("%-24s chunk ricostruiti %d | mediana %6.2f ms | 95%% %6.2f ms | massimo %6.2f ms" % [
		BENCH_CLASS_LABELS[_bench_class], _bench_chunks_rebuilt.size(),
		samples[count >> 1] * 0.001, samples[int(count * 0.95)] * 0.001, samples[-1] * 0.001,
	])
