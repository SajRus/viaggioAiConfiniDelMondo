class_name MainMenu
extends Control

const GAME_SCENE: String = "res://src/game.tscn"

@onready var _seed: LineEdit = %Seed
@onready var _new: Button = %New
@onready var _load: Button = %Load
@onready var _quit: Button = %Quit
@onready var _status: Label = %Status


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	_new.pressed.connect(_on_new_pressed)
	_load.pressed.connect(_on_load_pressed)
	_quit.pressed.connect(_on_quit_pressed)
	_load.disabled = not SaveSystem.has_save()


func _on_new_pressed() -> void:
	var state: WorldSave = WorldSave.new()
	state.world_seed = WorldSave.seed_from_text(_seed.text)
	_open_game(state)


func _on_load_pressed() -> void:
	var state: WorldSave = SaveSystem.read()
	if state == null:
		_status.text = "Salvataggio danneggiato o non leggibile"
		return
	_open_game(state)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _open_game(state: WorldSave) -> void:
	SaveSystem.request_world(state)
	get_tree().change_scene_to_file(GAME_SCENE)
