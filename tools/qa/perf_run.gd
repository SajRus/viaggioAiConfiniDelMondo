extends Node

const GAME_SCENE: String = "res://src/game.tscn"
const NO_VSYNC_ARGUMENT: String = "--no-vsync"
const LOG_PATH: String = "user://perf_log.csv"
const WORLD_SEED: int = 1234
const WARMUP_FRAMES: int = 60
const DURATION_USEC: int = 30000000
const EDIT_INTERVAL_FRAMES: int = 45
const PATH_HEIGHT: float = 62.0
const PATH_RADIUS: float = 100.0
const PATH_LOOK_AHEAD: float = 0.01
const PATH_LOOK_DOWN: float = 3.0
const USEC_PER_SECOND: float = 1000000.0
const USEC_PER_MILLISECOND: float = 1000.0
# With vsync every frame lasts about 16.67 ms with some jitter: a frame that
# lasts one and a half periods has missed at least one refresh.
const MISSED_FRAME_USEC: int = 25000
const STALL_USEC: int = 500000
const TARGET_WINDOW_SIZE: Vector2i = Vector2i(1920, 1080)

var _world: World
var _player: Player
var _camera: Camera3D
var _load_start_usec: int = 0
var _load_usec: int = 0
var _warmup_left: int = WARMUP_FRAMES
var _start_usec: int = 0
var _last_usec: int = 0
var _running: bool = false
var _frames: PackedInt64Array = PackedInt64Array()
var _edits: PackedInt64Array = PackedInt64Array()
var _frames_until_edit: int = EDIT_INTERVAL_FRAMES
var _restore_cell: Vector3i = Vector3i(-1, -1, -1)
var _restore_id: int = BlockTable.AIR


func _ready() -> void:
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = TARGET_WINDOW_SIZE
	# macOS can resize the window to the whole screen: the scene still renders
	# at 1080p and is scaled to the window.
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	get_window().content_scale_size = TARGET_WINDOW_SIZE
	if NO_VSYNC_ARGUMENT in OS.get_cmdline_user_args():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	var state: WorldSave = WorldSave.new()
	state.world_seed = WORLD_SEED
	SaveSystem.request_world(state)
	var scene: PackedScene = load(GAME_SCENE)
	var game: Node = scene.instantiate()
	_load_start_usec = Time.get_ticks_usec()
	add_child(game)
	_world = game.get_node("World")
	_player = game.get_node("Player")
	_camera = game.get_node("Player/Head/Camera")
	_world.loaded.connect(_on_world_loaded)


func _process(_delta: float) -> void:
	if not _running:
		return
	var now: int = Time.get_ticks_usec()
	if _warmup_left > 0:
		_warmup_left -= 1
		_start_usec = now
		_last_usec = now
		_place_on_path(0.0)
		return
	_frames.append(now - _last_usec)
	_last_usec = now
	var progress: float = float(now - _start_usec) / float(DURATION_USEC)
	if progress >= 1.0:
		_finish()
		return
	_place_on_path(progress)
	_edit_step()


func _on_world_loaded() -> void:
	_load_usec = Time.get_ticks_usec() - _load_start_usec
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_player.human_controlled = false
	_running = true


func _path_point(progress: float) -> Vector3:
	var center: float = _world.chunks_per_side * ChunkData.SIZE_X * 0.5
	return Vector3(
		center + PATH_RADIUS * sin(TAU * progress),
		PATH_HEIGHT,
		center + PATH_RADIUS * sin(2.0 * TAU * progress)
	)


func _place_on_path(progress: float) -> void:
	var point: Vector3 = _path_point(progress)
	var target: Vector3 = _path_point(progress + PATH_LOOK_AHEAD) + Vector3.DOWN * PATH_LOOK_DOWN
	_camera.look_at_from_position(point, target)


func _edit_step() -> void:
	_frames_until_edit -= 1
	if _frames_until_edit > 0:
		return
	_frames_until_edit = EDIT_INTERVAL_FRAMES
	if _restore_cell.y >= 0:
		_world.manager.set_block(_restore_cell.x, _restore_cell.y, _restore_cell.z, _restore_id)
		_restore_cell = Vector3i(-1, -1, -1)
	else:
		var x: int = floori(_camera.global_position.x)
		var z: int = floori(_camera.global_position.z)
		var y: int = _world.data.surface_height(x, z)
		_restore_cell = Vector3i(x, y, z)
		_restore_id = _world.data.get_block_world(x, y, z)
		_world.manager.set_block(x, y, z, BlockTable.AIR)
	var start: int = Time.get_ticks_usec()
	_world.manager.flush()
	_edits.append(Time.get_ticks_usec() - start)


func _finish() -> void:
	var stalls: PackedStringArray = _stall_report()
	var frames: PackedInt64Array = _frames.duplicate()
	frames.sort()
	var edits: PackedInt64Array = _edits.duplicate()
	edits.sort()
	var count: int = frames.size()
	var total_usec: int = 0
	var missed: int = 0
	for frame_usec: int in frames:
		total_usec += frame_usec
		if frame_usec > MISSED_FRAME_USEC:
			missed += 1
	var average_fps: float = count / (total_usec / USEC_PER_SECOND)
	var worst_one_percent_ms: float = frames[int(count * 0.99)] / USEC_PER_MILLISECOND
	var worst_ms: float = frames[-1] / USEC_PER_MILLISECOND
	var load_s: float = _load_usec / USEC_PER_SECOND
	var edit_median_ms: float = edits[edits.size() >> 1] / USEC_PER_MILLISECOND
	var edit_worst_ms: float = edits[-1] / USEC_PER_MILLISECOND
	var block_bytes: int = _world.data.chunks.size() * ChunkData.VOLUME
	var static_mb: float = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var video_mb: float = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	var render_size: Vector2i = get_viewport().get_texture().get_size()
	print("Perf: Godot %s, debug build %s, rendering %s, window %s, vsync %s" % [
		Engine.get_version_info()["string"], OS.is_debug_build(), render_size, get_window().size,
		DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED,
	])
	print("RNF-01: %d frame | FPS medio %.1f | 1%% peggiore %.2f ms | massimo %.2f ms | frame saltati: %d" % [
		count, average_fps, worst_one_percent_ms, worst_ms, missed,
	])
	print("Blocchi oltre 500 ms: %d %s" % [stalls.size(), ", ".join(stalls)])
	print("RNF-03: caricamento %.3f s" % load_s)
	print("RNF-04: %d modifiche | mediana %.2f ms | massimo %.2f ms" % [edits.size(), edit_median_ms, edit_worst_ms])
	print("RNF-05: dati blocco %d byte | memoria statica %.0f MB | memoria video %.0f MB" % [block_bytes, static_mb, video_mb])
	_append_log([
		Time.get_datetime_string_from_system(), average_fps, worst_one_percent_ms, worst_ms, missed,
		load_s, edit_median_ms, edit_worst_ms, block_bytes,
	])
	get_tree().quit()


## Lists when each long freeze happened, in seconds from the start of the path.
func _stall_report() -> PackedStringArray:
	var stalls: PackedStringArray = []
	var elapsed_usec: int = 0
	for frame_usec: int in _frames:
		elapsed_usec += frame_usec
		if frame_usec > STALL_USEC:
			stalls.append("%.1f s (%.0f ms)" % [elapsed_usec / USEC_PER_SECOND, frame_usec / USEC_PER_MILLISECOND])
	return stalls


func _append_log(values: Array) -> void:
	var existed: bool = FileAccess.file_exists(LOG_PATH)
	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.READ_WRITE if existed else FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	if not existed:
		file.store_line("data,fps_medio,uno_percento_ms,massimo_ms,frame_saltati,caricamento_s,modifica_mediana_ms,modifica_massimo_ms,byte_blocchi")
	file.store_line(",".join(values.map(func(value: Variant) -> String: return str(value))))
	file.close()
