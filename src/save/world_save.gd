class_name WorldSave
extends RefCounted

var world_seed: int = 0
var has_player_position: bool = false
var player_position: Vector3 = Vector3.ZERO
var diffs: BlockDiffLog = BlockDiffLog.new()


## Empty text picks a random seed; anything that is not a number is hashed.
static func seed_from_text(text: String) -> int:
	var trimmed: String = text.strip_edges()
	if trimmed.is_empty():
		return randi()
	if trimmed.is_valid_int():
		return trimmed.to_int()
	return trimmed.hash()
