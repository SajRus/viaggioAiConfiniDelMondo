class_name ItemIcons
extends RefCounted


static func icon(atlas: Texture2D, item: int) -> AtlasTexture:
	var tile: int = ItemTable.icon_tile(item)
	var texture: AtlasTexture = AtlasTexture.new()
	texture.atlas = atlas
	texture.region = Rect2(
		BlockTable.tile_uv_origin(tile) * atlas.get_size(), Vector2.ONE * BlockTable.ATLAS_TILE_PIXELS
	)
	return texture
