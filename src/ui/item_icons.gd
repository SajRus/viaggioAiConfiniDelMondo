class_name ItemIcons
extends RefCounted


## The atlas tile of an item: the side of a block, or the tool icon.
static func icon(atlas: Texture2D, item: int) -> AtlasTexture:
	var tile: int = ItemTable.tool_tile(item) if ItemTable.is_tool_item(item) else BlockRegistry.tile_side[item]
	var texture: AtlasTexture = AtlasTexture.new()
	texture.atlas = atlas
	texture.region = Rect2(
		BlockTable.tile_uv_origin(tile) * atlas.get_size(), Vector2.ONE * BlockTable.ATLAS_TILE_PIXELS
	)
	return texture
