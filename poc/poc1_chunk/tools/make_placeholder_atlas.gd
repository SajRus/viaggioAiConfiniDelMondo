extends SceneTree

const OUTPUT_PATH: String = "res://assets/atlas.png"
const TILES: int = BlockTable.ATLAS_COLUMNS * BlockTable.ATLAS_COLUMNS
const TILE_SIZE: int = BlockTable.ATLAS_TILE_PIXELS
const CLEAR: Color = Color(0.0, 0.0, 0.0, 0.0)
const GRASS: Color = Color8(92, 150, 62)
const DIRT: Color = Color8(125, 88, 56)
const STONE: Color = Color8(125, 125, 130)
const SAND: Color = Color8(219, 203, 144)
const BARK: Color = Color8(92, 66, 40)
const WOOD: Color = Color8(176, 136, 84)
const LEAF: Color = Color8(54, 112, 44)
const PLANK: Color = Color8(190, 148, 92)
const FRAME: Color = Color8(190, 225, 235)
const MAGENTA: Color = Color8(255, 0, 255)

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 1
	var atlas: Image = Image.create_empty(
		BlockTable.ATLAS_COLUMNS * TILE_SIZE, BlockTable.ATLAS_COLUMNS * TILE_SIZE, false, Image.FORMAT_RGBA8
	)
	for tile: int in TILES:
		_paint_tile(atlas, tile)
	var error: Error = atlas.save_png(OUTPUT_PATH)
	quit(0 if error == OK else 1)


func _paint_tile(atlas: Image, tile: int) -> void:
	var origin: Vector2i = Vector2i(BlockTable.tile_uv_origin(tile) * float(BlockTable.ATLAS_COLUMNS)) * TILE_SIZE
	for y: int in TILE_SIZE:
		for x: int in TILE_SIZE:
			atlas.set_pixelv(origin + Vector2i(x, y), _pixel(tile, x, y))


func _pixel(tile: int, x: int, y: int) -> Color:
	var edge: bool = x == 0 or y == 0 or x == TILE_SIZE - 1 or y == TILE_SIZE - 1
	match tile:
		BlockTable.TILE_GRASS_TOP:
			return _noisy(GRASS)
		BlockTable.TILE_GRASS_SIDE:
			return _noisy(GRASS if y < 3 else DIRT)
		BlockTable.TILE_DIRT:
			return _noisy(DIRT)
		BlockTable.TILE_STONE:
			return _noisy(STONE)
		BlockTable.TILE_SAND:
			return _noisy(SAND)
		BlockTable.TILE_LOG_TOP:
			return _noisy(BARK if edge else WOOD)
		BlockTable.TILE_LOG_SIDE:
			return _noisy(BARK if x % 4 != 0 else BARK.darkened(0.3))
		BlockTable.TILE_LEAVES:
			return CLEAR if _rng.randf() < 0.2 else _noisy(LEAF)
		BlockTable.TILE_PLANKS:
			return _noisy(PLANK.darkened(0.35) if y % 4 == 3 else PLANK)
		BlockTable.TILE_GLASS:
			return FRAME if edge else CLEAR
	return MAGENTA


func _noisy(base: Color) -> Color:
	return base.darkened(_rng.randf_range(0.0, 0.14))
