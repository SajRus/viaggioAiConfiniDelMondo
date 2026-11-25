class_name MeshingJob
extends RefCounted

## Layer ranges per chunk: one per performance core of the development Mac.
const SLICES: int = 4

var chunk: ChunkData
var slices: Array[ScanSlice] = []
var surfaces: Array[ChunkSurfaceArrays] = []


## Splits the [param layers] that hold blocks into ranges of similar size.
func _init(job_chunk: ChunkData, layers: int) -> void:
	chunk = job_chunk
	for slice: int in SLICES:
		var first_y: int = roundi(float(layers) * slice / SLICES)
		var end_y: int = roundi(float(layers) * (slice + 1) / SLICES)
		slices.append(ScanSlice.new(chunk, first_y, end_y))


## Joins the slices in layer order and builds the surfaces.
func finish(mesher: ChunkMesher) -> void:
	var faces: PackedInt32Array = PackedInt32Array()
	for slice: ScanSlice in slices:
		faces.append_array(slice.faces)
	surfaces = mesher.surfaces_from_faces(chunk, faces)
