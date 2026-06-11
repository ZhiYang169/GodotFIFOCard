class_name LevelDatabase
extends RefCounted

const LEVEL_PATH = "res://data/Levels/"

static func get_level(level_id:int) -> LevelConfig:
	var path = LEVEL_PATH + "level_%02d.tres" % level_id
	if ResourceLoader.exists(path):
		return load(path)
	return _generate_default(level_id)

static func _generate_default(level_id:int) -> LevelConfig:
	var config = LevelConfig.new()
	config.level_id = level_id
	config.target_score = 1000+1000*(level_id-1)*2
	return config
	# config.hand_size = 
