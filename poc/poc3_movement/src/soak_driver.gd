class_name SoakDriver
extends Node

const TICKS_PER_SECOND: int = 60
const TOLERANCE: float = 0.02
const EDGE_MARGIN: float = 14.0
const FALL_LIMIT: float = -2.0
const STUCK_WINDOW_TICKS: int = 300
const STUCK_DISTANCE: float = 0.05
const MAX_REPORTED_VIOLATIONS: int = 10

var _player: Player
var _world: WorldData
var _table: BlockTable
var _total_ticks: int
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _tick: int = 0
var _next_decision_tick: int = 0
var _violations: int = 0
var _falls: int = 0
var _stuck_resets: int = 0
var _airborne_ticks: int = 0
var _distance: float = 0.0
var _previous_position: Vector3 = Vector3.ZERO
var _window_start_position: Vector3 = Vector3.ZERO


func _init(player: Player, world: WorldData, table: BlockTable, seconds: int, bot_seed: int) -> void:
	_player = player
	_world = world
	_table = table
	_total_ticks = seconds * TICKS_PER_SECOND
	_rng.seed = bot_seed


func _ready() -> void:
	_previous_position = _player.global_position
	_window_start_position = _player.global_position


func _physics_process(_delta: float) -> void:
	_tick += 1
	_check_player()
	if _tick >= _next_decision_tick:
		_decide()
	if _tick % STUCK_WINDOW_TICKS == 0:
		_reset_if_stuck()
	if _tick >= _total_ticks:
		_finish()


func _check_player() -> void:
	var feet: Vector3 = _player.global_position
	_distance += Vector2(feet.x - _previous_position.x, feet.z - _previous_position.z).length()
	_previous_position = feet
	if not _player.is_on_floor():
		_airborne_ticks += 1
	if feet.y < FALL_LIMIT:
		_falls += 1
		_report("caduta fuori dal mondo", feet)
		_respawn_random()
		return
	if VoxelProbe.box_overlaps_solid(_world, _table, VoxelProbe.player_box(feet, TOLERANCE)):
		_violations += 1
		_report("giocatore dentro un blocco", feet)


func _report(reason: String, feet: Vector3) -> void:
	if _violations + _falls <= MAX_REPORTED_VIOLATIONS:
		print("VIOLAZIONE tick %d: %s a %s, velocità %s" % [_tick, reason, feet, _player.velocity])


func _decide() -> void:
	var center: Vector2 = Vector2(_world.chunks_x, _world.chunks_z) * ChunkData.SIZE_X * 0.5
	var flat: Vector2 = Vector2(_player.global_position.x, _player.global_position.z)
	var wish: Vector2 = Vector2.from_angle(_rng.randf_range(0.0, TAU))
	if absf(flat.x - center.x) > center.x - EDGE_MARGIN or absf(flat.y - center.y) > center.y - EDGE_MARGIN:
		wish = (center - flat).normalized()
	_player.wish_move = Vector2(wish.x, -wish.y)
	_player.wish_jump = _rng.randf() < 0.55
	_next_decision_tick = _tick + _rng.randi_range(12, 90)


func _reset_if_stuck() -> void:
	if _player.global_position.distance_to(_window_start_position) < STUCK_DISTANCE:
		_stuck_resets += 1
		_respawn_random()
	_window_start_position = _player.global_position


func _respawn_random() -> void:
	var size: int = _world.chunks_x * ChunkData.SIZE_X
	var x: int = _rng.randi_range(16, size - 16)
	var z: int = _rng.randi_range(16, size - 16)
	_player.velocity = Vector3.ZERO
	_player.global_position = Vector3(x + 0.5, _world.surface_height(x, z) + 1.5, z + 0.5)
	_previous_position = _player.global_position
	_window_start_position = _player.global_position


func _finish() -> void:
	print("Soak: %d tick (%.1f min simulati) | percorsi %.0f blocchi | in aria %.0f%% | sbloccato %d volte" % [
		_tick, _tick / float(TICKS_PER_SECOND * 60), _distance, 100.0 * _airborne_ticks / float(_tick), _stuck_resets,
	])
	print("Violazioni: dentro un blocco %d | cadute dal mondo %d" % [_violations, _falls])
	get_tree().quit(1 if _violations + _falls > 0 else 0)
