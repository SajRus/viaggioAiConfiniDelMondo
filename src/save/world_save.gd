class_name WorldSave
extends RefCounted

## Format version the save was read from; 0 for a world that was never saved.
var source_version: int = 0
var world_seed: int = 0
## Chunks per side of [member blocks]; 0 keeps the size of the world scene.
var chunks_per_side: int = 0
## Every block of the world, chunk after chunk. Empty when the terrain must be generated.
var blocks: PackedByteArray = PackedByteArray()
var has_player_position: bool = false
var player_position: Vector3 = Vector3.ZERO
## Version 1 saves only: edits to reapply over the generated terrain.
var diffs: BlockDiffLog = BlockDiffLog.new()


## Empty text picks a random seed; anything that is not a number is hashed.
static func seed_from_text(text: String) -> int:
	var trimmed: String = text.strip_edges()
	if trimmed.is_empty():
		return randi()
	if trimmed.is_valid_int():
		return trimmed.to_int()
	return trimmed.hash()
