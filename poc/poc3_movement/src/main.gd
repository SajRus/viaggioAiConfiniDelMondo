extends Node3D

enum Phase { GENERATING, MESHING, RUNNING }
enum BenchStage { REBUILD, SAMPLE_LOOP, SAMPLE_IDLE_LOOP }

const REBUILD_BENCH_ARGUMENT: String = "--rebuild-bench"
const SOAK_ARGUMENT: String = "--soak"
const SOAK_SECONDS_PREFIX: String = "--soak-seconds="
const SOAK_SEED_PREFIX: String = "--soak-seed="
const DEFAULT_SOAK_SECONDS: int = 1800
const WORLD_SEED: int = 1234
const COURSE_SEED: int = 99
const CHUNKS_PER_SIDE_BITS: int = 4
const CHUNKS_PER_SIDE: int = 1 << CHUNKS_PER_SIDE_BITS
const LOAD_BUDGET_USEC: int = 12000
const SPAWN_COLUMN: int = 128
const BENCH_SETTLE_TICKS: int = 120
const BENCH_ITERATIONS: int = 30

@export var _material: Material

var _table: BlockTable = BlockTable.new()
var _mesher: ChunkMesher = ChunkMesher.new(_table)
var _generator: TerrainGenerator = TerrainGenerator.new(WORLD_SEED)
var _world: WorldData = WorldData.new(CHUNKS_PER_SIDE, CHUNKS_PER_SIDE)
var _nodes: Array[ChunkNode] = []
var _phase: Phase = Phase.GENERATING
var _next_chunk: int = 0
var _load_start_usec: int = 0
var _load_total_usec: int = 0
var _soak: bool = false
var _soak_seconds: int = DEFAULT_SOAK_SECONDS
var _soak_seed: int = 1
var _rebuild_bench: bool = false
var _bench_settle_left: int = BENCH_SETTLE_TICKS
var _bench_targets: Array[int] = []
var _bench_stage: BenchStage = BenchStage.REBUILD
var _bench_last_tick_usec: int = 0
var _bench_mesh: PackedInt64Array = PackedInt64Array()
var _bench_collision: PackedInt64Array = PackedInt64Array()
var _bench_total: PackedInt64Array = PackedInt64Array()
var _bench_loop: PackedInt64Array = PackedInt64Array()
var _bench_idle_loop: PackedInt64Array = PackedInt64Array()

@onready var _chunk_root: Node3D = $Chunks
@onready var _player: Player = $Player
@onready var _stats: Label = $Hud/Stats


func _ready() -> void:
	_parse_arguments()
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_player.human_controlled = not _soak and not _rebuild_bench
	_load_start_usec = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	match _phase:
		Phase.GENERATING:
			_generate_step()
		Phase.MESHING:
			_mesh_step()
	_update_stats()


func _physics_process(_delta: float) -> void:
	if _phase == Phase.RUNNING and _rebuild_bench:
		_rebuild_bench_step()


func _unhandled_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo:
		if key.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif key.keycode == KEY_R and _phase == Phase.RUNNING:
			var index: int = _chunk_index_under_player()
			_nodes[index].rebuild(_mesher, _world.chunks[index])


func _parse_arguments() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument == SOAK_ARGUMENT:
			_soak = true
		elif argument == REBUILD_BENCH_ARGUMENT:
			_rebuild_bench = true
		elif argument.begins_with(SOAK_SECONDS_PREFIX):
			_soak_seconds = argument.trim_prefix(SOAK_SECONDS_PREFIX).to_int()
		elif argument.begins_with(SOAK_SEED_PREFIX):
			_soak_seed = argument.trim_prefix(SOAK_SEED_PREFIX).to_int()


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
	print("Caricamento con collisioni: %.3f s, motore fisico %s" % [
		_load_total_usec * 0.000001, ProjectSettings.get_setting("physics/3d/physics_engine"),
	])
	if _soak:
		add_child(SoakDriver.new(_player, _world, _table, _soak_seconds, _soak_seed))


func _chunk_index_under_player() -> int:
	var feet: Vector3 = _player.global_position
	var chunk_x: int = clampi(floori(feet.x) >> WorldData.CHUNK_BITS, 0, CHUNKS_PER_SIDE - 1)
	var chunk_z: int = clampi(floori(feet.z) >> WorldData.CHUNK_BITS, 0, CHUNKS_PER_SIDE - 1)
	return chunk_x + (chunk_z << CHUNKS_PER_SIDE_BITS)


func _update_stats() -> void:
	if _phase != Phase.RUNNING:
		_stats.text = "Generazione del mondo... chunk %d/%d" % [_next_chunk, _world.chunks.size()]
		return
	var index: int = _chunk_index_under_player()
	_stats.text = "%d FPS | posizione %s | a terra %s | ultimo rebuild mesh %.2f ms, collisione %.2f ms\nClic per il mouse, WASD, Spazio salta, R ricostruisce il chunk, Esc libera il mouse" % [
		Engine.get_frames_per_second(), _player.global_position.snappedf(0.01), _player.is_on_floor(),
		_nodes[index].last_mesh_usec * 0.001, _nodes[index].last_collision_usec * 0.001,
	]


func _rebuild_bench_step() -> void:
	var now: int = Time.get_ticks_usec()
	var previous_loop_usec: int = now - _bench_last_tick_usec
	_bench_last_tick_usec = now
	if _bench_settle_left > 0:
		_bench_settle_left -= 1
		if _bench_settle_left == 0:
			_bench_targets = [_chunk_index_under_player(), _busiest_chunk_index()]
			print("Rebuild con mesh e collisione, %d iterazioni, debug build: %s" % [BENCH_ITERATIONS, OS.is_debug_build()])
		return
	match _bench_stage:
		BenchStage.REBUILD:
			var node: ChunkNode = _nodes[_bench_targets[0]]
			node.rebuild(_mesher, _world.chunks[_bench_targets[0]])
			_bench_mesh.append(node.last_mesh_usec)
			_bench_collision.append(node.last_collision_usec)
			_bench_total.append(node.last_mesh_usec + node.last_collision_usec)
			_bench_stage = BenchStage.SAMPLE_LOOP
		BenchStage.SAMPLE_LOOP:
			_bench_loop.append(previous_loop_usec)
			_bench_stage = BenchStage.SAMPLE_IDLE_LOOP
		BenchStage.SAMPLE_IDLE_LOOP:
			_bench_idle_loop.append(previous_loop_usec)
			_bench_stage = BenchStage.REBUILD
			if _bench_idle_loop.size() == BENCH_ITERATIONS:
				_print_bench_target()
				_bench_targets.remove_at(0)
				if _bench_targets.is_empty():
					get_tree().quit()


func _busiest_chunk_index() -> int:
	var busiest: int = 0
	for index: int in _nodes.size():
		if _nodes[index].face_count > _nodes[busiest].face_count:
			busiest = index
	return busiest


func _print_bench_target() -> void:
	var node: ChunkNode = _nodes[_bench_targets[0]]
	for samples: PackedInt64Array in [_bench_mesh, _bench_collision, _bench_total, _bench_loop, _bench_idle_loop]:
		samples.sort()
	# Consecutive ticks only measure one physics step when nothing else paces
	# the loop: headless with --fixed-fps 60.
	var loop_report: String = ""
	if DisplayServer.get_name() == "headless":
		loop_report = " | ciclo con rebuild %s | ciclo a vuoto %s" % [_format_samples(_bench_loop), _format_samples(_bench_idle_loop)]
	print("Chunk %d, %d facce | mesh %s | collisione %s | totale %s%s (mediana/massimo in ms)" % [
		_bench_targets[0], node.face_count,
		_format_samples(_bench_mesh), _format_samples(_bench_collision), _format_samples(_bench_total), loop_report,
	])
	_bench_mesh.clear()
	_bench_collision.clear()
	_bench_total.clear()
	_bench_loop.clear()
	_bench_idle_loop.clear()


func _format_samples(samples: PackedInt64Array) -> String:
	return "%.2f/%.2f" % [samples[BENCH_ITERATIONS >> 1] * 0.001, samples[-1] * 0.001]
