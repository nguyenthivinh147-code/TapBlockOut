extends Resource
## Block body SDFs baked by tools/bake_sdf.gd for every block shape in data/levels and data/road_trip.
## Shape i is a FORMAT_RH image of Pudding.image_for(): width sizes[2i], height sizes[2i + 1], its bytes compressed
## with zstd one shape at a time in data[offsets[i] .. offsets[i + 1]) so only the shapes in use are ever unpacked.

@export var signature: String = ""  # Pudding.signature() at bake time; Pudding ignores the bank when it differs
@export var keys: PackedStringArray = PackedStringArray()  # Pudding.shape_key() of each shape, sorted
@export var sizes: PackedInt32Array = PackedInt32Array()
@export var offsets: PackedInt32Array = PackedInt32Array()  # keys.size() + 1 entries, the last is data.size()
@export var data: PackedByteArray = PackedByteArray()
