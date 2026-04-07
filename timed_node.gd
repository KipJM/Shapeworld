extends Node

class_name TimedNode

func _enter_tree() -> void:
	var tm: TimeManager = %TimeManager
	tm.tick.connect(_tick)
	

func _tick(minute, delta) -> void:
	pass
