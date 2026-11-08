extends Node3D

const BENCH_ARGUMENT: String = "--bench"
const BENCH_ITERATIONS: int = 30
const ORBIT_SPEED: float = 0.008
const ZOOM_STEP: float = 2.0
const MIN_PITCH: float = -1.4
const MAX_PITCH: float = 1.4
const FOCUS: Vector3 = Vector3(8.0, 22.0, 8.0)

var _table: BlockTable = BlockTable.new()
var _mesher: ChunkMesher = ChunkMesher.new(_table)
var _chunk: ChunkData = ChunkData.new()
var _last_rebuild_usec: int = 0
var _yaw: float = 0.7
var _pitch: float = -0.45
var _distance: float = 42.0
var _pattern_name: String = ""

@onready var _chunk_instance: MeshInstance3D = $Chunk
@onready var _camera: Camera3D = $Camera
@onready var _stats: Label = $Hud/Stats


func _ready() -> void:
	if BENCH_ARGUMENT in OS.get_cmdline_user_args():
		await get_tree().process_frame
		_run_bench()
		get_tree().quit()
		return
	_show_pattern("colline", ChunkPatterns.fill_hills)
	_update_camera()


func _process(_delta: float) -> void:
	_stats.text = "%s | ricostruzione %.2f ms | %d FPS\n1 colline, 2 pieno, 3 scacchiera, R ricostruisci, trascina per ruotare, rotella per zoom" % [
		_pattern_name, _last_rebuild_usec * 0.001, Engine.get_frames_per_second(),
	]


func _unhandled_input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_yaw -= motion.relative.x * ORBIT_SPEED
		_pitch = clampf(_pitch - motion.relative.y * ORBIT_SPEED, MIN_PITCH, MAX_PITCH)
		_update_camera()
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed:
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(_distance - ZOOM_STEP, ZOOM_STEP)
			_update_camera()
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance += ZOOM_STEP
			_update_camera()
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo:
		_handle_key(key.keycode)


func _handle_key(keycode: Key) -> void:
	match keycode:
		KEY_1:
			_show_pattern("colline", ChunkPatterns.fill_hills)
		KEY_2:
			_show_pattern("pieno", ChunkPatterns.fill_solid)
		KEY_3:
			_show_pattern("scacchiera", ChunkPatterns.fill_checkerboard)
		KEY_R:
			_rebuild()


func _show_pattern(pattern_name: String, fill: Callable) -> void:
	_pattern_name = pattern_name
	_chunk.blocks.fill(BlockTable.AIR)
	fill.call(_chunk)
	_rebuild()


func _rebuild() -> void:
	var start: int = Time.get_ticks_usec()
	_chunk_instance.mesh = _mesher.build_mesh(_chunk)
	_last_rebuild_usec = Time.get_ticks_usec() - start


func _update_camera() -> void:
	var direction: Vector3 = Vector3.BACK.rotated(Vector3.RIGHT, _pitch).rotated(Vector3.UP, _yaw)
	_camera.look_at_from_position(FOCUS + direction * _distance, FOCUS)


func _run_bench() -> void:
	print("PoC 1 bench: %d iterations, Godot %s, debug build: %s" % [
		BENCH_ITERATIONS, Engine.get_version_info()["string"], OS.is_debug_build(),
	])
	_bench_pattern("colline", ChunkPatterns.fill_hills)
	_bench_pattern("pieno", ChunkPatterns.fill_solid)
	_bench_pattern("scacchiera", ChunkPatterns.fill_checkerboard)


func _bench_pattern(pattern_name: String, fill: Callable) -> void:
	_show_pattern(pattern_name, fill)
	var samples: PackedInt64Array = PackedInt64Array()
	for _iteration: int in BENCH_ITERATIONS:
		_rebuild()
		samples.append(_last_rebuild_usec)
	samples.sort()
	var faces: int = 0
	for surface: ChunkSurfaceArrays in _mesher.build_surfaces(_chunk):
		faces += surface.face_count
	print("%-11s facce %6d | mediana %8.2f ms | massimo %8.2f ms" % [
		pattern_name, faces, samples[samples.size() >> 1] * 0.001, samples[-1] * 0.001,
	])
