extends Node

const DEFAULT_SAVE_PATH: String = "user://world.sav"
const TEMPORARY_SUFFIX: String = ".tmp"

var save_path: String = DEFAULT_SAVE_PATH

var _request: WorldSave = null


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


## Writes to a temporary file first, so a failed save keeps the previous one.
func write(state: WorldSave) -> bool:
	var temporary_path: String = save_path + TEMPORARY_SUFFIX
	var file: FileAccess = FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(SaveCodec.encode(state))
	var written: bool = file.get_error() == OK
	file.close()
	return written and DirAccess.rename_absolute(temporary_path, save_path) == OK


## Returns null when there is no save or it cannot be read. A save of an older
## version is first copied to [method backup_path], before it is ever rewritten.
func read() -> WorldSave:
	if not has_save():
		return null
	var state: WorldSave = SaveCodec.decode(FileAccess.get_file_as_bytes(save_path))
	if state != null and state.source_version != SaveCodec.VERSION:
		var backup: String = backup_path(state.source_version)
		if not FileAccess.file_exists(backup) and DirAccess.copy_absolute(save_path, backup) != OK:
			return null
	return state


func backup_path(version: int) -> String:
	return "%s.v%d.bak" % [save_path, version]


func request_world(state: WorldSave) -> void:
	_request = state


## Returns the world the game scene must open, then forgets it.
func take_request() -> WorldSave:
	var state: WorldSave = _request
	_request = null
	if state == null:
		state = WorldSave.new()
		state.world_seed = randi()
	return state
