class_name ScanSlice
extends RefCounted

## A range of layers of one chunk to scan. Each worker writes only its own slice.
var chunk: ChunkData
var first_y: int
var end_y: int
var faces: PackedInt32Array = PackedInt32Array()


func _init(slice_chunk: ChunkData, slice_first_y: int, slice_end_y: int) -> void:
	chunk = slice_chunk
	first_y = slice_first_y
	end_y = slice_end_y


func run(mesher: ChunkMesher) -> void:
	faces = mesher.scan_faces(chunk, first_y, end_y)
