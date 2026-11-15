class_name PauseMenu
extends Control

signal save_requested
signal main_menu_requested
signal quit_requested

var enabled: bool = false

@onready var _resume: Button = %Resume
@onready var _save: Button = %Save
@onready var _main_menu: Button = %MainMenu
@onready var _quit: Button = %Quit
@onready var _status: Label = %Status


func _ready() -> void:
	_resume.pressed.connect(close)
	_save.pressed.connect(save_requested.emit)
	_main_menu.pressed.connect(main_menu_requested.emit)
	_quit.pressed.connect(quit_requested.emit)
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if enabled and key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


func open() -> void:
	_status.text = ""
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func show_status(text: String) -> void:
	_status.text = text
