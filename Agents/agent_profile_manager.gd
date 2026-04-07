extends Node
class_name AgentProfileManager

@export_category("Global params")
@export var walk_speed: float

@export_category("Profiles")
## number does not have to add up to one.
@export var profile_distribution: Dictionary[AgentProfile, float]


func random_agent_profile() -> AgentProfile:
	return WeightedRandom.get_weighted_random(profile_distribution)


## Get the walkspeed influenced by TimeManager's timescale
func get_walk_speed() -> float:
	return walk_speed * (%TimeManager as TimeManager).time_scale
