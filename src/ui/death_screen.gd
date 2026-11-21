class_name DeathScreen
extends Control

signal respawn_requested

@onready var _respawn: Button = %Respawn


func _ready() -> void:
	_respawn.pressed.connect(respawn_requested.emit)
	visible = false


func open() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
