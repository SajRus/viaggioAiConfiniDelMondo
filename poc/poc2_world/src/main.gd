extends Node3D

enum Phase { GENERATING, MESHING, RUNNING }

const BENCH_ARGUMENT: String = "--bench"
const BENCH_VSYNC_ARGUMENT: String = "--bench-vsync"
const WORLD_SEED: int = 1234
const CHUNKS_PER_SIDE_BITS: int = 4
const CHUNKS_PER_SIDE: int = 1 << CHUNKS_PER_SIDE_BITS
const WORLD_SPAN: float = 256.0
const LOAD_BUDGET_USEC: int = 12000
const FLY_SPEED: float = 24.0
const LOOK_SPEED: float = 0.003
const MAX_PITCH: float = 1.5

const BENCH_WARMUP_FRAMES: int = 60
const BENCH_DURATION_USEC: int = 20000000
const PATH_HEIGHT: float = 62.0
const PATH_RADIUS: float = 100.0
const PATH_LOOK_AHEAD: float = 0.01
const PATH_LOOK_DOWN: float = 3.0

var _table: BlockTable = BlockTable.new()
var _mesher: ChunkMesher = ChunkMesher.new(_table)
var _generator: TerrainGenerator = TerrainGenerator.new(WORLD_SEED)
var _world: WorldData = WorldData.new(CHUNKS_PER_SIDE, CHUNKS_PER_SIDE)
@export var _material: Material

var _phase: Phase = Phase.GENERATING
var _next_chunk: int = 0
var _load_start_usec: int = 0
var _generate_usec: int = 0
var _mesh_usec: int = 0
var _load_total_usec: int = 0
var _yaw: float = -0.8
var _pitch: float = -0.35
var _bench: bool = false
var _bench_warmup_left: int = BENCH_WARMUP_FRAMES
var _bench_start_usec: int = 0
var _bench_last_usec: int = 0
var _bench_frames: PackedInt64Array = PackedInt64Array()

@onready var _chunk_root: Node3D = $Chunks
@onready var _camera: Camera3D = $Camera
@onready var _stats: Label = $Hud/Stats


func _ready() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	_bench = BENCH_ARGUMENT in arguments or BENCH_VSYNC_ARGUMENT in arguments
	if BENCH_ARGUMENT in arguments:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	_camera.position = Vector3(40.0, 60.0, 40.0)
	_apply_look()
	_load_start_usec = Time.get_ticks_usec()


func _process(delta: float) -> void:
	match _phase:
		Phase.GENERATING:
			_generate_step()
		Phase.MESHING:
			_mesh_step()
		Phase.RUNNING:
			if _bench:
				_bench_step()
			else:
				_fly(delta)
	_update_stats()


func _unhandled_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and key.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= motion.relative.x * LOOK_SPEED
		_pitch = clampf(_pitch - motion.relative.y * LOOK_SPEED, -MAX_PITCH, MAX_PITCH)
		_apply_look()


func _generate_step() -> void:
	var start: int = Time.get_ticks_usec()
	var now: int = start
	while _next_chunk < _world.chunks.size() and now - start < LOAD_BUDGET_USEC:
		var chunk_z: int = _next_chunk >> CHUNKS_PER_SIDE_BITS
		var chunk_x: int = _next_chunk & (CHUNKS_PER_SIDE - 1)
		_generator.fill_chunk(_world.chunks[_next_chunk], chunk_x, chunk_z)
		_next_chunk += 1
		now = Time.get_ticks_usec()
	_generate_usec += now - start
	if _next_chunk == _world.chunks.size():
		_next_chunk = 0
		_phase = Phase.MESHING


func _mesh_step() -> void:
	var start: int = Time.get_ticks_usec()
	var now: int = start
	while _next_chunk < _world.chunks.size() and now - start < LOAD_BUDGET_USEC:
		_add_chunk_instance(_next_chunk)
		_next_chunk += 1
		now = Time.get_ticks_usec()
	_mesh_usec += now - start
	if _next_chunk == _world.chunks.size():
		_load_total_usec = Time.get_ticks_usec() - _load_start_usec
		_phase = Phase.RUNNING
		if _bench:
			_print_load_report()


func _add_chunk_instance(chunk_index: int) -> void:
	var chunk: ChunkData = _world.chunks[chunk_index]
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = _mesher.build_mesh(chunk)
	instance.material_override = _material
	var chunk_z: int = chunk_index >> CHUNKS_PER_SIDE_BITS
	var chunk_x: int = chunk_index & (CHUNKS_PER_SIDE - 1)
	instance.position = Vector3(chunk_x * ChunkData.SIZE_X, 0.0, chunk_z * ChunkData.SIZE_Z)
	_chunk_root.add_child(instance)


func _fly(delta: float) -> void:
	var input: Vector3 = Vector3(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	_camera.position += _camera.global_basis * input * FLY_SPEED * delta


func _apply_look() -> void:
	_camera.rotation = Vector3(_pitch, _yaw, 0.0)


func _update_stats() -> void:
	if _phase != Phase.RUNNING:
		_stats.text = "Generazione del mondo... chunk %d/%d" % [_next_chunk, _world.chunks.size()]
		return
	_stats.text = "%d FPS | caricamento %.2f s | draw call %d\nClic per catturare il mouse, WASD e Q/E per volare, Esc per liberare il mouse" % [
		Engine.get_frames_per_second(),
		_load_total_usec * 0.000001,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
	]


func _path_point(progress: float) -> Vector3:
	var center: float = WORLD_SPAN * 0.5
	return Vector3(
		center + PATH_RADIUS * sin(TAU * progress),
		PATH_HEIGHT,
		center + PATH_RADIUS * sin(2.0 * TAU * progress)
	)


func _bench_step() -> void:
	var now: int = Time.get_ticks_usec()
	if _bench_warmup_left > 0:
		_bench_warmup_left -= 1
		_bench_start_usec = now
		_bench_last_usec = now
		_place_on_path(0.0)
		return
	_bench_frames.append(now - _bench_last_usec)
	_bench_last_usec = now
	var progress: float = float(now - _bench_start_usec) / float(BENCH_DURATION_USEC)
	if progress >= 1.0:
		_print_frame_report()
		get_tree().quit()
		return
	_place_on_path(progress)


func _place_on_path(progress: float) -> void:
	var point: Vector3 = _path_point(progress)
	var target: Vector3 = _path_point(progress + PATH_LOOK_AHEAD) + Vector3.DOWN * PATH_LOOK_DOWN
	_camera.look_at_from_position(point, target)


func _print_load_report() -> void:
	print("PoC 2: %s, debug build: %s, viewport %s" % [
		Engine.get_version_info()["string"], OS.is_debug_build(), get_viewport().get_visible_rect().size,
	])
	print("Caricamento: generazione %.3f s | mesh %.3f s | totale %.3f s" % [
		_generate_usec * 0.000001, _mesh_usec * 0.000001, _load_total_usec * 0.000001,
	])


func _print_frame_report() -> void:
	var worst_usec: int = 0
	var worst_at_usec: int = 0
	var elapsed_usec: int = 0
	for frame_usec: int in _bench_frames:
		elapsed_usec += frame_usec
		if frame_usec > worst_usec:
			worst_usec = frame_usec
			worst_at_usec = elapsed_usec
	var sorted: PackedInt64Array = _bench_frames.duplicate()
	sorted.sort()
	var count: int = sorted.size()
	var total_usec: int = 0
	for frame_usec: int in sorted:
		total_usec += frame_usec
	var slow_index: int = int(count * 0.99)
	print("Percorso: %d frame | FPS medio %.1f | 1%% peggiore %.2f ms | massimo %.2f ms al secondo %.1f" % [
		count, count / (total_usec * 0.000001), sorted[slow_index] * 0.001, sorted[-1] * 0.001, worst_at_usec * 0.000001,
	])
	print("Draw call %d | primitive %d" % [
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
	])
