extends Node

const GAME_SCENE: String = "res://src/game.tscn"
const SECONDS_PREFIX: String = "--seconds="
const SEED_PREFIX: String = "--seed="
const DEFAULT_SECONDS: int = 1800
const WORLD_SEED: int = 1234
const TICKS_PER_SECOND: int = 60
const TOLERANCE: float = 0.02
const EDGE_MARGIN: float = 12.0
const STUCK_WINDOW_TICKS: int = 300
const STUCK_DISTANCE: float = 0.05
const MAX_REPORTED: int = 8
const FRONT_REACH: float = 0.45
const PLACED_IDS: PackedInt32Array = [BlockTable.STONE, BlockTable.GLASS, BlockTable.PLANKS]

var _world: World
var _player: Player
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _total_ticks: int = DEFAULT_SECONDS * TICKS_PER_SECOND
var _running: bool = false
var _tick: int = 0
var _next_decision_tick: int = 0
var _next_edit_tick: int = 0
var _wish: Vector2 = Vector2.ZERO
var _inside_block: int = 0
var _left_world: int = 0
var _stuck_resets: int = 0
var _placed: int = 0
var _broken: int = 0
var _window_start: Vector3 = Vector3.ZERO


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(SECONDS_PREFIX):
			_total_ticks = argument.trim_prefix(SECONDS_PREFIX).to_int() * TICKS_PER_SECOND
		elif argument.begins_with(SEED_PREFIX):
			_rng.seed = argument.trim_prefix(SEED_PREFIX).to_int()
	var state: WorldSave = WorldSave.new()
	state.world_seed = WORLD_SEED
	SaveSystem.request_world(state)
	var scene: PackedScene = load(GAME_SCENE)
	var game: Node = scene.instantiate()
	add_child(game)
	_world = game.get_node("World")
	_player = game.get_node("Player")
	_world.loaded.connect(_on_world_loaded)


func _on_world_loaded() -> void:
	_player.human_controlled = false
	_window_start = _player.global_position
	_running = true


# Runs before the player moves in the same tick, like a click does: the
# player can step into a cell whose collision is only rebuilt at frame end.
func _physics_process(_delta: float) -> void:
	if not _running:
		return
	_tick += 1
	_check_player()
	if _tick >= _next_decision_tick:
		_decide()
	if _tick >= _next_edit_tick:
		_edit_near_player()
	if _tick % STUCK_WINDOW_TICKS == 0:
		_reset_if_stuck()
	if _tick >= _total_ticks:
		_finish()


func _check_player() -> void:
	var feet: Vector3 = _player.global_position
	var span: float = _world.chunks_per_side * ChunkData.SIZE_X
	if feet.x < 0.0 or feet.z < 0.0 or feet.x > span or feet.z > span or feet.y < -0.5:
		_left_world += 1
		_report("fuori dal mondo", feet)
		_respawn()
		return
	if VoxelAudit.box_overlaps_solid(_world.data, BlockRegistry, Player.box_at(feet, TOLERANCE)):
		_inside_block += 1
		_report("dentro un blocco", feet)


func _report(reason: String, feet: Vector3) -> void:
	if _inside_block + _left_world <= MAX_REPORTED:
		print("VIOLAZIONE tick %d: %s a %s, velocità %s" % [_tick, reason, feet, _player.velocity])


func _decide() -> void:
	var center: float = _world.chunks_per_side * ChunkData.SIZE_X * 0.5
	var flat: Vector2 = Vector2(_player.global_position.x, _player.global_position.z)
	_wish = Vector2.from_angle(_rng.randf_range(0.0, TAU))
	if absf(flat.x - center) > center - EDGE_MARGIN or absf(flat.y - center) > center - EDGE_MARGIN:
		_wish = (Vector2.ONE * center - flat).normalized()
	_player.wish_move = Vector2(_wish.x, -_wish.y)
	_player.wish_jump = _rng.randf() < 0.45
	_next_decision_tick = _tick + _rng.randi_range(12, 90)


func _edit_near_player() -> void:
	_next_edit_tick = _tick + _rng.randi_range(4, 20)
	var feet: Vector3 = _player.global_position
	var front: Vector3 = feet + Vector3(_wish.x, 0.0, _wish.y) * FRONT_REACH
	var target: Vector3i = Vector3i(front.floor()) + Vector3i(0, _rng.randi_range(0, 1), 0)
	if _rng.randf() < 0.6:
		var hit: VoxelHit = VoxelHit.new(target + Vector3i.DOWN, Vector3i.UP, 1.0)
		var id: int = PLACED_IDS[_rng.randi_range(0, PLACED_IDS.size() - 1)]
		if BlockEditor.place_block(_world.manager, hit, id, feet):
			_placed += 1
	else:
		var column: Vector2i = Vector2i(target.x + _rng.randi_range(-2, 2), target.z + _rng.randi_range(-2, 2))
		var y: int = _world.data.surface_height(column.x, column.y)
		if y >= 1 and _world.manager.set_block(column.x, y, column.y, BlockTable.AIR):
			_broken += 1


func _reset_if_stuck() -> void:
	if _player.global_position.distance_to(_window_start) < STUCK_DISTANCE:
		_stuck_resets += 1
		_respawn()
	_window_start = _player.global_position


func _respawn() -> void:
	var span: int = _world.chunks_per_side * ChunkData.SIZE_X
	var x: int = _rng.randi_range(16, span - 16)
	var z: int = _rng.randi_range(16, span - 16)
	_player.velocity = Vector3.ZERO
	_player.global_position = Vector3(x + 0.5, _world.data.surface_height(x, z) + 1.5, z + 0.5)
	_window_start = _player.global_position


func _finish() -> void:
	set_physics_process(false)
	_world.manager.flush()
	var built: int = 0
	for node: ChunkNode in _world.chunk_nodes():
		built += node.face_count
	var expected: int = VoxelAudit.expected_face_count(_world.data, BlockRegistry)
	print("Soak: %.1f min simulati | piazzati %d | rotti %d | sbloccato %d volte" % [
		_tick / float(TICKS_PER_SECOND * 60), _placed, _broken, _stuck_resets,
	])
	print("Violazioni: dentro un blocco %d | fuori dal mondo %d | facce costruite %d, attese %d" % [
		_inside_block, _left_world, built, expected,
	])
	get_tree().quit(1 if _inside_block + _left_world > 0 or built != expected else 0)
