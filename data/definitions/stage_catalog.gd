class_name StageCatalog
extends Resource
## Daftar semua stage secara berurutan, disimpan di data/stage_catalog.tres.

const PATH := "res://data/stage_catalog.tres"

@export var stages: Array[StageData] = []
@export var prologue_dialog: PackedStringArray = []
@export var ending_dialog: PackedStringArray = []
## Penutup setelah arak-arakan keliling desa.
@export var epilogue_dialog: PackedStringArray = []


static func load_default() -> StageCatalog:
	return load(PATH) as StageCatalog


func get_stage(number: int) -> StageData:
	for stage: StageData in stages:
		if stage.stage_number == number:
			return stage
	return null
