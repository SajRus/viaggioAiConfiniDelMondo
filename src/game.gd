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
	_world.start_generation(_session.world_seed, _session.diffs)


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


func _on_save_requested() -> void:
	var state: WorldSave = WorldSave.new()
	state.world_seed = _session.world_seed
	state.has_player_position = true
	state.player_position = _player.global_position
	state.diffs = _world.manager.diffs
	_pause.show_status("Partita salvata" if SaveSystem.write(state) else "Salvataggio non riuscito")


func _on_main_menu_requested() -> void:
	_pause.close()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_quit_requested() -> void:
	get_tree().quit()
