class_name ChunkManager
extends RefCounted

var diffs: BlockDiffLog

var _world: WorldData
var _mesher: ChunkMesher
var _nodes: Array[ChunkNode]
var _dirty_indices: PackedInt32Array = PackedInt32Array()


func _init(
	world: WorldData, mesher: ChunkMesher, nodes: Array[ChunkNode], block_diffs: BlockDiffLog = BlockDiffLog.new()
) -> void:
	diffs = block_diffs
	_world = world
	_mesher = mesher
	_nodes = nodes


func get_block(x: int, y: int, z: int) -> int:
	return _world.get_block_world(x, y, z)


## Writes one block and marks what must be rebuilt. Returns false when nothing changed.
func set_block(x: int, y: int, z: int, id: int) -> bool:
	if not _world.is_inside(x, y, z) or _world.get_block_world(x, y, z) == id:
		return false
	_world.set_block_world(x, y, z, id)
	var chunk_x: int = x >> WorldData.CHUNK_BITS
	var chunk_z: int = z >> WorldData.CHUNK_BITS
	var local_x: int = x & WorldData.CHUNK_MASK
	var local_z: int = z & WorldData.CHUNK_MASK
	diffs.record(chunk_x + _world.chunks_x * chunk_z, ChunkData.index_of(local_x, y, local_z), id)
	_mark_dirty(chunk_x, chunk_z)
	if local_x == 0:
		_mark_dirty(chunk_x - 1, chunk_z)
	elif local_x == WorldData.CHUNK_MASK:
		_mark_dirty(chunk_x + 1, chunk_z)
	if local_z == 0:
		_mark_dirty(chunk_x, chunk_z - 1)
	elif local_z == WorldData.CHUNK_MASK:
		_mark_dirty(chunk_x, chunk_z + 1)
	return true


## Rebuilds every marked chunk and returns their indices. The block scan is
## split into layer ranges that run in parallel on worker threads, then each
## chunk turns its faces into surfaces, also in parallel. Mesh and collision
## are created here on the main thread, so the edit shows in this frame.
func flush() -> PackedInt32Array:
	var rebuilt: PackedInt32Array = _dirty_indices
	_dirty_indices = PackedInt32Array()
	if rebuilt.is_empty():
		return rebuilt
	var jobs: Array[MeshingJob] = []
	var slices: Array[ScanSlice] = []
	for index: int in rebuilt:
		var job: MeshingJob = MeshingJob.new(_world.chunks[index], _mesher.top_layer(_world.chunks[index]) + 1)
		jobs.append(job)
		slices.append_array(job.slices)
	_run_on_workers(func(slice: int) -> void: slices[slice].run(_mesher), slices.size())
	_run_on_workers(func(job: int) -> void: jobs[job].finish(_mesher), jobs.size())
	for job: int in jobs.size():
		_nodes[rebuilt[job]].apply_surfaces(jobs[job].surfaces)
		jobs[job].chunk.dirty = false
	return rebuilt


func _run_on_workers(task: Callable, count: int) -> void:
	var group: int = WorkerThreadPool.add_group_task(task, count)
	WorkerThreadPool.wait_for_group_task_completion(group)


func _mark_dirty(chunk_x: int, chunk_z: int) -> void:
	if chunk_x < 0 or chunk_x >= _world.chunks_x or chunk_z < 0 or chunk_z >= _world.chunks_z:
		return
	var index: int = chunk_x + _world.chunks_x * chunk_z
	var chunk: ChunkData = _world.chunks[index]
	if not chunk.dirty:
		chunk.dirty = true
		_dirty_indices.append(index)
