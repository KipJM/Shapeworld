extends Node
class_name AgentProfileManager

@export_category("Global params")
@export var walk_speed: float
## what percent of agents is aware of fastpass or online fastpass
@export_range(0,1,0.1) var fastpass_aware_percent: float
## what percent of agents is aware of online wait times checking.
@export_range(0,1,0.1) var onlinewait_aware_percent: float

## max amount of fastpass an agent can hold at a time
@export var max_fastpasses: int



@export_category("Profiles")
## number does not have to add up to one.
@export var profile_distribution: Dictionary[AgentProfile, float]


func random_agent_profile() -> AgentProfile:
	return WeightedRandom.get_weighted_random(profile_distribution)


## Get the walkspeed influenced by TimeManager's timescale
func get_walk_speed() -> float:
	return walk_speed * (%TimeManager as TimeManager).time_scale
