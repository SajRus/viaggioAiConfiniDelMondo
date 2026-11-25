extends Node3D

## A world of terrain version 2, the player in the middle and the giant 100
## blocks away. Without arguments a person plays; with --giant-chase the player
## stands still and the run checks that the giant reaches them without getting
## stuck, and how long every rebuild after a broken block takes.

const CHASE_ARGUMENT: String = "--giant-chase"
const BUNKER_ARGUMENT: String = "--bunker"
const NO_VSYNC_ARGUMENT: String = "--no-vsync"
const SEED_PREFIX: String = "--world-seed="
const SHOT_DIR_PREFIX: String = "--shot-dir="
const START_DISTANCE: float = 100.0
## Golden angle: each seed starts the giant from a different side.
const START_ANGLE_STEP: float = 2.39996
const SEARCH_RADIUS: int = 12
const REACH_DISTANCE: float = 2.4
const REACH_HEIGHT: float = 3.0
## The giant must get at least a block closer within this time, or it is stuck.
const PROGRESS_SECONDS: float = 15.0
const PROGRESS_BLOCKS: float = 1.0
const CHASE_LIMIT_SECONDS: float = 300.0
const BUNKER_RADIUS: int = 3
const BUNKER_HEIGHT: int = 4
const FRAME_BUDGET_USEC: int = 16667
const WARM_UP_USEC: int = 2000000
const SHOT_EVERY_SECONDS: float = 5.0

var _chase: bool = false
var _bunker: bool = false
var _world_seed: int = 1
var _shot_dir: String = ""
var _running: bool = false
var _finished: bool = false
var _time: float = 0.0
var _start_feet: Vector3
var _best_distance: float = INF
var _best_time: float = 0.0
var _problems: PackedStringArray = PackedStringArray()
var _start_usec: int = 0
var _last_frame_usec: int = 0
var _frame_usec: PackedInt64Array = PackedInt64Array()
var _next_shot: float = 0.0
var _restarts: int = 0

@onready var _world: World = $World
@onready var _player: Player = $Player
@onready var _giant: Giant = $Giant
@onready var _stats: Label = $Hud/Stats
@onready var _banner: Label = $Hud/Banner


func _ready() -> void:
	_parse_arguments()
	_player.human_controlled = not _chase
	_world.loaded.connect(_on_world_loaded)
	_world.start_generation(_world_seed)
	_banner.text = "Generazione del mondo..."


func _physics_process(delta: float) -> void:
	if not _running or _finished:
		return
	_time += delta
	var player_feet: Vector3 = _player.global_position
	_giant.goal = player_feet
	if _chase:
		_player.look_at_point(_giant.global_position + Vector3.UP * 2.5)
	var flat: float = Vector2(player_feet.x - _giant.global_position.x, player_feet.z - _giant.global_position.z).length()
	if flat < _best_distance - PROGRESS_BLOCKS:
		_best_distance = flat
		_best_time = _time
	if flat <= REACH_DISTANCE and absf(player_feet.y - _giant.global_position.y) <= REACH_HEIGHT:
		_banner.text = "Il portatore di mondi ti ha raggiunto"
		if _chase:
			_finish(true)
		else:
			_running = false
		return
	if _chase and _time - _best_time > PROGRESS_SECONDS:
		_problems.append("fermo da %.0f s a %.1f blocchi, in %s" % [
			PROGRESS_SECONDS, flat, GiantPlanner.Action.keys()[_giant.action]
		])
		_problems.append("gigante in %s, a terra %s, contro un muro %s" % [
			_giant.global_position, _giant.is_on_floor(), _giant.is_on_wall()
		])
		_finish(false)
	elif _chase and _time > CHASE_LIMIT_SECONDS:
		_problems.append("non arriva entro %.0f s" % CHASE_LIMIT_SECONDS)
		_finish(false)


func _process(_delta: float) -> void:
	if not _running:
		return
	var now: int = Time.get_ticks_usec()
	if now - _start_usec > WARM_UP_USEC and _last_frame_usec > 0:
		_frame_usec.append(now - _last_frame_usec)
	_last_frame_usec = now
	if not _shot_dir.is_empty() and _time >= _next_shot:
		_next_shot += SHOT_EVERY_SECONDS
		get_viewport().get_texture().get_image().save_png(_shot_dir.path_join("giant_%03d.png" % roundi(_time)))
	var distance: float = _player.global_position.distance_to(_giant.global_position)
	_stats.text = "Gigante: %s, a %.1f blocchi\nSalti %d, blocchi rotti %d, ricostruzioni %d\nTempo %.1f s, FPS %d%s" % [
		GiantPlanner.Action.keys()[_giant.action], distance, _giant.jumps, _giant.breaks,
		_world.flush_usec.size(), _time, Engine.get_frames_per_second(),
		"" if _chase else "\nR: il gigante riparte da 100 blocchi",
	]


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if _chase or key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif key.physical_keycode == KEY_R and _world.is_ready_to_play():
		_restarts += 1
		_place_giant(_world_seed + _restarts)
		_banner.text = ""
		_running = true


func _parse_arguments() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument == CHASE_ARGUMENT:
			_chase = true
		elif argument == BUNKER_ARGUMENT:
			_bunker = true
		elif argument == NO_VSYNC_ARGUMENT:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		elif argument.begins_with(SEED_PREFIX):
			_world_seed = argument.trim_prefix(SEED_PREFIX).to_int()
		elif argument.begins_with(SHOT_DIR_PREFIX):
			_shot_dir = argument.trim_prefix(SHOT_DIR_PREFIX)


func _on_world_loaded() -> void:
	var middle: int = _world.chunks_per_side * ChunkData.SIZE_X >> 1
	var player_column: Vector2i = _open_ground(Vector2i(middle, middle), 0)
	_player.teleport(_feet_on(player_column, 0))
	if _bunker:
		_build_bunker(player_column)
	_giant.setup(_world.data, _world.manager)
	_place_giant(_world_seed)
	_player.process_mode = Node.PROCESS_MODE_INHERIT
	_giant.process_mode = Node.PROCESS_MODE_INHERIT
	_banner.text = ""
	_start_usec = Time.get_ticks_usec()
	_running = true


## Puts the giant on open ground about 100 blocks from the player.
func _place_giant(angle_seed: int) -> void:
	var player_feet: Vector3 = _player.global_position
	var angle: float = angle_seed * START_ANGLE_STEP
	var wanted: Vector2i = Vector2i(
		floori(player_feet.x + cos(angle) * START_DISTANCE), floori(player_feet.z + sin(angle) * START_DISTANCE)
	)
	var column: Vector2i = _open_ground(wanted, 1, Vector2(player_feet.x, player_feet.z))
	_giant.teleport(_feet_on(column, 1))
	_start_feet = _giant.global_position
	_best_distance = INF
	_best_time = _time


## The column nearest [param wanted] whose square of [param radius] has ground,
## not trees, on top. With [param away_from], only columns at least
## [constant START_DISTANCE] from it count.
func _open_ground(wanted: Vector2i, radius: int, away_from: Vector2 = Vector2.INF) -> Vector2i:
	var size: int = _world.chunks_per_side * ChunkData.SIZE_X
	for ring: int in SEARCH_RADIUS + 1:
		for dz: int in range(-ring, ring + 1):
			for dx: int in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dz)) != ring:
					continue
				var column: Vector2i = (wanted + Vector2i(dx, dz)).clamp(Vector2i.ONE * (radius + 2), Vector2i.ONE * (size - radius - 3))
				var too_close: bool = (
					away_from.is_finite() and (Vector2(column) + Vector2.ONE * 0.5).distance_to(away_from) < START_DISTANCE
				)
				if not too_close and _is_open(column, radius):
					return column
	return wanted


func _is_open(column: Vector2i, radius: int) -> bool:
	for dz: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			var x: int = column.x + dx
			var z: int = column.y + dz
			var top: int = _world.data.get_block_world(x, _world.data.surface_height(x, z), z)
			if top == BlockTable.LOG or top == BlockTable.LEAVES:
				return false
	return true


## Feet on the highest ground of the square of [param radius] around [param column].
func _feet_on(column: Vector2i, radius: int) -> Vector3:
	var highest: int = 0
	for dz: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			highest = maxi(highest, _world.data.surface_height(column.x + dx, column.y + dz))
	return Vector3(column.x + 0.5, highest + 1.0, column.y + 0.5)


## A ring of stone around the player, as high as the giant above the highest
## ground nearby: on a slope a lower wall would be a step to jump.
func _build_bunker(column: Vector2i) -> void:
	var top: int = 0
	var reach: int = BUNKER_RADIUS + 2
	for dz: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			top = maxi(top, _ground_height(column.x + dx, column.y + dz) + BUNKER_HEIGHT)
	for dz: int in range(-BUNKER_RADIUS, BUNKER_RADIUS + 1):
		for dx: int in range(-BUNKER_RADIUS, BUNKER_RADIUS + 1):
			if maxi(absi(dx), absi(dz)) != BUNKER_RADIUS:
				continue
			var x: int = column.x + dx
			var z: int = column.y + dz
			for y: int in range(_ground_height(x, z) + 1, top + 1):
				_world.manager.set_block(x, y, z, BlockTable.STONE)
	_world.manager.flush()


## The highest block of the column that is not part of a tree.
func _ground_height(x: int, z: int) -> int:
	for y: int in range(ChunkData.SIZE_Y - 1, -1, -1):
		var id: int = _world.data.get_block_world(x, y, z)
		if id != BlockTable.AIR and id != BlockTable.LOG and id != BlockTable.LEAVES:
			return y
	return -1


func _finish(reached: bool) -> void:
	_finished = true
	print(_report(reached))
	get_tree().quit(0 if reached and _problems.is_empty() else 1)


func _report(reached: bool) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("== PoC 6, seed %d%s ==" % [_world_seed, ", bunker" if _bunker else ""])
	lines.append("Partenza a %.1f blocchi (dislivello %.0f), tempo simulato %.1f s, %s" % [
		Vector2(_start_feet.x - _player.global_position.x, _start_feet.z - _player.global_position.z).length(),
		_start_feet.y - _player.global_position.y, _time, "raggiunto" if reached else "NON raggiunto",
	])
	var types: PackedStringArray = PackedStringArray()
	for id: int in _giant.broken_types:
		types.append("%s %d" % [_block_name(id), _giant.broken_types[id]])
	lines.append("Salti %d, blocchi rotti %d (%s)" % [_giant.jumps, _giant.breaks, ", ".join(types)])
	lines.append(_flush_report())
	if DisplayServer.get_name() != "headless" and _frame_usec.size() > 0:
		lines.append(_frame_report())
	lines.append("Problemi: %d" % _problems.size())
	lines.append_array(_problems)
	lines.append("ESITO: %s" % ("OK" if reached and _problems.is_empty() else "FALLITO"))
	return "\n".join(lines)


func _flush_report() -> String:
	var count: int = _world.flush_usec.size()
	if count == 0:
		return "Ricostruzioni: nessuna"
	var sorted: PackedInt64Array = _world.flush_usec.duplicate()
	sorted.sort()
	var over: int = 0
	var most_chunks: int = 0
	for index: int in count:
		if _world.flush_usec[index] > FRAME_BUDGET_USEC:
			over += 1
		most_chunks = maxi(most_chunks, _world.flush_chunks[index])
	return "Ricostruzioni %d: mediana %.1f ms, 95° percentile %.1f ms, massimo %.1f ms, oltre 16,7 ms %d, chunk per ricostruzione fino a %d" % [
		count, sorted[count >> 1] / 1000.0, sorted[int(count * 0.95)] / 1000.0, sorted[count - 1] / 1000.0,
		over, most_chunks,
	]


func _frame_report() -> String:
	var sorted: PackedInt64Array = _frame_usec.duplicate()
	sorted.sort()
	var count: int = sorted.size()
	return "Frame %d (%dx%d, vsync %s): mediana %.1f ms, 95° percentile %.1f ms, massimo %.1f ms" % [
		count, int(get_viewport().get_visible_rect().size.x), int(get_viewport().get_visible_rect().size.y),
		"sì" if DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED else "no",
		sorted[count >> 1] / 1000.0, sorted[int(count * 0.95)] / 1000.0, sorted[count - 1] / 1000.0,
	]


static func _block_name(id: int) -> String:
	match id:
		BlockTable.GRASS:
			return "erba"
		BlockTable.DIRT:
			return "terra"
		BlockTable.STONE:
			return "pietra"
		BlockTable.SAND:
			return "sabbia"
		BlockTable.LOG:
			return "tronco"
		BlockTable.LEAVES:
			return "foglie"
	return "blocco %d" % id
