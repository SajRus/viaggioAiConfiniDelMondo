class_name SaveFixtures
extends RefCounted

## Real save files of every format version, in test/save/fixtures/.
## Never regenerate one: a new version adds its own file.

const V1: String = "res://test/save/fixtures/world_v1.sav"
const V2: String = "res://test/save/fixtures/world_v2.sav"
const WORLD_SEED: int = 1234
const PLAYER_POSITION: Vector3 = Vector3(130.5, 45.25, 126.5)
## Blocks edited in the version 1 file: a small house and a dug hole.
const V1_EDITS: int = 69
## The saved world, the same in every fixture.
const WORLD_SHA256: String = "76b81094a321ee95e601fc770d9af20398179eadf6cedcfbbebb224486630e5e"
## Terrain of seed 1234 as the MVP generated it. Version 1 saves are rebuilt on it.
const V1_TERRAIN_SHA256: String = "15c8d6a671a187a476b4469837e4e906a3dfff60905d0d701e933e82b51676b5"


static func sha256(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()
