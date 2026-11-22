extends Node3D

## Arena, player and dragon. Without arguments a person plays; with
## --dragon-soak the bot wanders while the dragon flies its cycles and every
## state is checked; with --dragon-fight the bot fights until the dragon falls.

const SOAK_ARGUMENT: String = "--dragon-soak"
const FIGHT_ARGUMENT: String = "--dragon-fight"
const CYCLES_PREFIX: String = "--cycles="
const SEED_PREFIX: String = "--soak-seed="
const WEAPON_PREFIX: String = "--weapon="
const SHOT_DIR_PREFIX: String = "--shot-dir="
## Frame times without waiting for the screen: what a frame really costs.
const NO_VSYNC_ARGUMENT: String = "--no-vsync"
const WEAPON_ARGUMENTS: PackedStringArray = ["hand", "pickaxe", "wooden", "stone"]
const DEFAULT_CYCLES: int = 50
const ARENA_CENTER: Vector3 = Vector3(0.0, 1.0, 0.0)
const ARENA_HALF_SIZE: float = 7.5
const SPAWN: Vector3 = Vector3(0.0, 1.0, 6.0)
## Simulated seconds after which a fight counts as lost.
const FIGHT_LIMIT_SECONDS: float = 900.0
const FRAME_BUDGET_USEC: int = 16667
## Loading and the first shader compilations are not part of the fight.
const WARM_UP_USEC: int = 2000000
## Seconds into a state before its picture is taken.
const SHOT_DELAY: float = 0.4
# One physics frame of slack on every time limit.
const FRAME_SLACK: float = 1.0 / 60.0

enum Mode { PLAY, SOAK, FIGHT }

var _mode: Mode = Mode.PLAY
var _cycles_wanted: int = DEFAULT_CYCLES
var _rng_seed: int = 1
var _brain: DragonBrain = DragonBrain.new(ARENA_CENTER, ARENA_HALF_SIZE)
var _combat: Combat = Combat.new()
var _health: Health = Health.new()
var _bot: ArenaBot
var _time: float = 0.0
var _cycles: int = 0
var _dives: int = 0
var _dive_hits: int = 0
var _damage_taken: int = 0
var _deaths: int = 0
var _problems: PackedStringArray = PackedStringArray()
var _longest: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0])
var _last_frame_usec: int = 0
var _frame_usec: PackedInt64Array = PackedInt64Array()
var _finished: bool = false
var _respawn_pending: bool = false
var _start_usec: int = 0
var _shot_dir: String = ""
var _shots_taken: PackedStringArray = PackedStringArray()

@onready var _player: Player = $Player
@onready var _dragon: Dragon = $Dragon
@onready var _stats: Label = $Hud/Stats
@onready var _banner: Label = $Hud/Banner


func _ready() -> void:
	_parse_arguments()
	_dragon.brain = _brain
	_brain.hit_player.connect(_on_hit_player)
	_brain.landed.connect(_on_landed)
	_brain.cycle_completed.connect(_on_cycle_completed)
	_brain.defeated.connect(_on_defeated)
	_health.died.connect(_on_player_died)
	_player.human_controlled = _mode == Mode.PLAY
	_player.teleport(SPAWN)
	# The dragon starts high above the arena, out of a level view.
	_player.look_at_point(_brain.position)
	if _mode != Mode.PLAY:
		_bot = ArenaBot.new(_rng_seed, ARENA_CENTER, ARENA_HALF_SIZE)
		_bot.fights = _mode == Mode.FIGHT
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_banner.text = ""
	_start_usec = Time.get_ticks_usec()


func _physics_process(delta: float) -> void:
	if _finished:
		return
	_time += delta
	if _respawn_pending:
		_respawn_pending = false
		_restart()
	_combat.update(delta)
	_health.update(delta)
	var wants_swing: bool = false
	if _bot != null:
		wants_swing = _bot.drive(delta, _player, _brain)
	elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		wants_swing = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if wants_swing and _combat.can_swing() and _brain.state != DragonBrain.State.DEFEATED:
		if _combat.swing(_player.eye_position(), _player.view_direction(), _brain) > 0:
			_dragon.flash()
	_brain.update(delta, _player.global_position)
	_audit()
	_check_end()


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	_take_shot()
	var warm: bool = now - _start_usec > WARM_UP_USEC
	if warm and _last_frame_usec > 0 and _brain.state != DragonBrain.State.DEFEATED:
		_frame_usec.append(now - _last_frame_usec)
	_last_frame_usec = now
	_stats.text = "Drago: %s, salute %d/%d\nTu: salute %d/%d, %s\nCicli %d, picchiate a segno %d/%d, FPS %d" % [
		DragonBrain.State.keys()[_brain.state], _brain.health, DragonBrain.MAX_HEALTH,
		_health.points, Health.MAX, _combat.weapon_name(),
		_cycles, _dive_hits, _dives, Engine.get_frames_per_second(),
	]


func _unhandled_input(event: InputEvent) -> void:
	if _mode != Mode.PLAY:
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo:
		if key.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif key.physical_keycode >= KEY_1 and key.physical_keycode <= KEY_4:
			_combat.weapon = (key.physical_keycode - KEY_1) as Combat.Weapon
		elif key.physical_keycode == KEY_R:
			_restart()
	elif event is InputEventMouseButton and event.is_pressed():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _parse_arguments() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument == SOAK_ARGUMENT:
			_mode = Mode.SOAK
		elif argument == FIGHT_ARGUMENT:
			_mode = Mode.FIGHT
		elif argument.begins_with(CYCLES_PREFIX):
			_cycles_wanted = argument.trim_prefix(CYCLES_PREFIX).to_int()
		elif argument.begins_with(SEED_PREFIX):
			_rng_seed = argument.trim_prefix(SEED_PREFIX).to_int()
		elif argument.begins_with(WEAPON_PREFIX):
			var index: int = WEAPON_ARGUMENTS.find(argument.trim_prefix(WEAPON_PREFIX))
			if index >= 0:
				_combat.weapon = index as Combat.Weapon
		elif argument == NO_VSYNC_ARGUMENT:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		elif argument.begins_with(SHOT_DIR_PREFIX):
			_shot_dir = argument.trim_prefix(SHOT_DIR_PREFIX)


## Every frame: the dragon stays in its air column and no state outlasts its limit.
func _audit() -> void:
	var state: DragonBrain.State = _brain.state
	_longest[state] = maxf(_longest[state], _brain.state_time)
	if state != DragonBrain.State.DEFEATED and _brain.state_time > _brain.max_seconds(state) + FRAME_SLACK:
		_problem("%s dura %.2f s, oltre il limite di %.2f s" % [
			DragonBrain.State.keys()[state], _brain.state_time, _brain.max_seconds(state)
		])
	if not _brain.is_inside_flight_volume(_brain.position):
		_problem("drago fuori dall'arena in %s" % _brain.position)


func _problem(text: String) -> void:
	# The same fault would repeat every frame: keep the first few.
	if _problems.size() < 20:
		_problems.append("t=%.2f s, ciclo %d: %s" % [_time, _cycles, text])


func _check_end() -> void:
	if _mode == Mode.SOAK and _cycles >= _cycles_wanted:
		_finish()
	elif _mode == Mode.FIGHT and (_brain.state == DragonBrain.State.DEFEATED or _time >= FIGHT_LIMIT_SECONDS):
		_finish()


func _finish() -> void:
	_finished = true
	print(_report())
	get_tree().quit(0 if _problems.is_empty() and _passed() else 1)


func _passed() -> bool:
	if _mode == Mode.FIGHT:
		return _brain.state == DragonBrain.State.DEFEATED
	return _cycles >= _cycles_wanted


func _report() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("== PoC 5, %s, seed %d ==" % ["prova di resistenza" if _mode == Mode.SOAK else "combattimento", _rng_seed])
	lines.append("Tempo simulato %.1f s, cicli completi %d" % [_time, _cycles])
	for state: int in [DragonBrain.State.CIRCLING, DragonBrain.State.DIVING, DragonBrain.State.LANDED, DragonBrain.State.RISING]:
		lines.append("  %s: più lungo %.2f s, limite %.2f s" % [
			DragonBrain.State.keys()[state], _longest[state], _brain.max_seconds(state as DragonBrain.State)
		])
	lines.append("Picchiate %d, a segno %d; danni subiti %d, morti %d" % [_dives, _dive_hits, _damage_taken, _deaths])
	if _mode == Mode.FIGHT:
		lines.append("Arma %s: colpi %d, a segno %d, drago %s" % [
			_combat.weapon_name(), _combat.swings, _combat.hits,
			"sconfitto" if _brain.state == DragonBrain.State.DEFEATED else "ancora vivo (%d)" % _brain.health,
		])
	if DisplayServer.get_name() != "headless" and _frame_usec.size() > 0:
		lines.append(_frame_report())
	lines.append("Problemi: %d" % _problems.size())
	lines.append_array(_problems)
	lines.append("ESITO: %s" % ("OK" if _problems.is_empty() and _passed() else "FALLITO"))
	return "\n".join(lines)


func _frame_report() -> String:
	var sorted: PackedInt64Array = _frame_usec.duplicate()
	sorted.sort()
	var over: int = 0
	for usec: int in sorted:
		if usec > FRAME_BUDGET_USEC + 1000:
			over += 1
	return "Frame %d (%dx%d, vsync %s): mediana %.1f ms, 95° percentile %.1f ms, massimo %.1f ms, oltre 17,7 ms %d" % [
		sorted.size(), int(get_viewport().get_visible_rect().size.x), int(get_viewport().get_visible_rect().size.y),
		"sì" if DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED else "no",
		sorted[sorted.size() >> 1] / 1000.0, sorted[int(sorted.size() * 0.95)] / 1000.0,
		sorted[sorted.size() - 1] / 1000.0, over,
	]


## Saves one picture of each state of the dragon, for whoever cannot watch the window.
func _take_shot() -> void:
	if _shot_dir.is_empty() or _brain.state_time < SHOT_DELAY:
		return
	var state_name: String = DragonBrain.State.keys()[_brain.state]
	if _shots_taken.has(state_name):
		return
	_shots_taken.append(state_name)
	get_viewport().get_texture().get_image().save_png(_shot_dir.path_join(state_name.to_lower() + ".png"))


func _restart() -> void:
	_brain.reset()
	_health.restore()
	_player.teleport(SPAWN)
	_player.look_at_point(_brain.position)
	_banner.text = ""


func _on_hit_player(damage: int, push: Vector3) -> void:
	_dive_hits += 1
	_damage_taken += damage
	_player.push(push)
	if _mode == Mode.SOAK:
		# The soak watches the dragon: the player must not die and reset it.
		return
	_health.damage(damage)


func _on_landed() -> void:
	_dives += 1


func _on_cycle_completed() -> void:
	_cycles += 1


func _on_defeated() -> void:
	_banner.text = "Drago sconfitto! R per ricominciare"


func _on_player_died() -> void:
	_deaths += 1
	# The blow arrives in the middle of the dragon's update: reset it on the next frame.
	_respawn_pending = true
