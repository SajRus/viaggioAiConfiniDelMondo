extends Node3D

const MAIN_MENU_SCENE: String = "res://src/ui/main_menu.tscn"

## Null in creative.
var inventory: Inventory = null
var health: Health = Health.new()

var _session: WorldSave

@onready var _world: World = $World
@onready var _player: Player = $Player
@onready var _interaction: BlockInteraction = $Player/Interaction
@onready var _hotbar_view: HotbarView = $Hud/Hotbar
@onready var _health_view: HealthView = $Hud/Health
@onready var _loading: Label = $Hud/Loading
@onready var _pause: PauseMenu = $PauseLayer/Pause
@onready var _inventory_view: InventoryView = $InventoryLayer/Inventory
@onready var _death: DeathScreen = $DeathLayer/Death


func _ready() -> void:
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_session = SaveSystem.take_request()
	if _session.survival:
		_setup_survival()
	_hotbar_view.setup(_interaction.hotbar, inventory)
	_world.loaded.connect(_on_world_loaded)
	_pause.save_requested.connect(_on_save_requested)
	_pause.main_menu_requested.connect(_on_main_menu_requested)
	_pause.quit_requested.connect(_on_quit_requested)
	if _session.chunks_per_side > 0:
		_world.chunks_per_side = _session.chunks_per_side
	# Version 1 saves hold only edits, made over the MVP terrain.
	var terrain: int = TerrainGenerator.VERSION_MVP if _session.source_version == 1 else TerrainGenerator.LATEST_VERSION
	_world.start_generation(_session.world_seed, _session.blocks, _session.diffs, terrain)
	_session.blocks = PackedByteArray()


func _process(delta: float) -> void:
	if not _world.is_ready_to_play():
		_loading.text = "Generazione del mondo... %d%%" % roundi(_world.load_progress() * 100.0)
	elif inventory != null:
		health.update(delta)


func is_survival() -> bool:
	return inventory != null


func _setup_survival() -> void:
	inventory = Inventory.new()
	inventory.load_slots(_session.inventory_items, _session.inventory_counts)
	health.restore(_session.health)
	_interaction.inventory = inventory
	_health_view.setup(health)
	_health_view.visible = true
	_inventory_view.setup(inventory)
	_inventory_view.opened.connect(_set_pause_enabled.bind(false))
	_inventory_view.closed.connect(_set_pause_enabled.bind(true))
	health.died.connect(_on_died)
	_death.respawn_requested.connect(_on_respawn_requested)
	_player.landed.connect(_on_player_landed)


func _on_world_loaded() -> void:
	_interaction.setup(_world.data, _world.manager)
	_player.teleport(_session.player_position if _session.has_player_position else _world.spawn_point())
	_player.process_mode = Node.PROCESS_MODE_INHERIT
	_player.human_controlled = true
	_loading.visible = false
	_pause.enabled = true
	_inventory_view.enabled = is_survival()
	# An older save is rewritten at once, while the world it describes is still
	# the one this version can rebuild. SaveSystem.read() kept a backup.
	if _session.source_version != 0 and _session.source_version != SaveCodec.VERSION:
		_save()


func _on_player_landed(fall_height: float) -> void:
	health.damage(Health.fall_damage(fall_height))


func _on_died() -> void:
	_interaction.release_break()
	_pause.enabled = false
	_inventory_view.enabled = false
	_death.open()


func _on_respawn_requested() -> void:
	health.restore()
	_player.teleport(_world.spawn_point())
	_death.close()
	_pause.enabled = true
	_inventory_view.enabled = true


func _set_pause_enabled(value: bool) -> void:
	_pause.enabled = value


func _on_save_requested() -> void:
	_pause.show_status("Partita salvata" if _save() else "Salvataggio non riuscito")


func _save() -> bool:
	var state: WorldSave = WorldSave.new()
	state.world_seed = _session.world_seed
	state.chunks_per_side = _world.chunks_per_side
	state.blocks = _world.data.to_bytes()
	state.has_player_position = true
	state.player_position = _player.global_position
	if is_survival():
		state.survival = true
		state.health = health.points
		state.inventory_items = inventory.items
		state.inventory_counts = inventory.counts
	return SaveSystem.write(state)


func _on_main_menu_requested() -> void:
	_pause.close()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_quit_requested() -> void:
	get_tree().quit()
