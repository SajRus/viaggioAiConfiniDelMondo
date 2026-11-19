extends Node3D

const MAIN_MENU_SCENE: String = "res://src/ui/main_menu.tscn"

var _session: WorldSave

@onready var _world: World = $World
@onready var _player: Player = $Player
@onready var _interaction: BlockInteraction = $Player/Interaction
@onready var _hotbar_view: HotbarView = $Hud/Hotbar
@onready var _loading: Label = $Hud/Loading
@onready var _pause: PauseMenu = $PauseLayer/Pause


func _ready() -> void:
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_hotbar_view.setup(_interaction.hotbar)
	_world.loaded.connect(_on_world_loaded)
	_pause.save_requested.connect(_on_save_requested)
	_pause.main_menu_requested.connect(_on_main_menu_requested)
	_pause.quit_requested.connect(_on_quit_requested)
	_session = SaveSystem.take_request()
	if _session.chunks_per_side > 0:
		_world.chunks_per_side = _session.chunks_per_side
	_world.start_generation(_session.world_seed, _session.blocks, _session.diffs)
	_session.blocks = PackedByteArray()


func _process(_delta: float) -> void:
	if not _world.is_ready_to_play():
		_loading.text = "Generazione del mondo... %d%%" % roundi(_world.load_progress() * 100.0)


func _on_world_loaded() -> void:
	_interaction.setup(_world.data, _world.manager)
	_player.global_position = _session.player_position if _session.has_player_position else _world.spawn_point()
	_player.process_mode = Node.PROCESS_MODE_INHERIT
	_player.human_controlled = true
	_loading.visible = false
	_pause.enabled = true
	# An older save is rewritten at once, while the world it describes is still
	# the one this version can rebuild. SaveSystem.read() kept a backup.
	if _session.source_version != 0 and _session.source_version != SaveCodec.VERSION:
		_save()


func _on_save_requested() -> void:
	_pause.show_status("Partita salvata" if _save() else "Salvataggio non riuscito")


func _save() -> bool:
	var state: WorldSave = WorldSave.new()
	state.world_seed = _session.world_seed
	state.chunks_per_side = _world.chunks_per_side
	state.blocks = _world.data.to_bytes()
	state.has_player_position = true
	state.player_position = _player.global_position
	return SaveSystem.write(state)


func _on_main_menu_requested() -> void:
	_pause.close()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_quit_requested() -> void:
	get_tree().quit()
