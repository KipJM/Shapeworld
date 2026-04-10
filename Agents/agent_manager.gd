extends TimedNode
class_name AgentManager

## How many total agents
@export var total_daily_agents: int
## Percentage of agents every hour. Hour:PERCENTAGE
@export var arrival_seed: Dictionary[int, float]

var entry_minute_distribution: Dictionary[int, int]

@export var agent_prefab: PackedScene
@export var agent_parent: Node

@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY)
var in_park_agents: Array[Agent] = []

var current_id: int = 0


## Schedule is defined by how many agents come in every minute i
## Modified from shapeland python script
func generate_arrival_schedule(perfect_arrivals: bool) -> Dictionary[int, int]:
	var schedule: Dictionary[int, int] = {}
	
	# percentage validatation, could be uneeded
	var total_pct := 0.0
	for pct: float in arrival_seed.values():
		total_pct += pct
	
	if !is_equal_approx(total_pct, 1.0) and !arrival_seed.is_empty():
		push_warning("Arrival schedule seed does not add up to 1. Expect undefined behavior")

	for exact_minute in range(%TimeManager.time_start * 60, %TimeManager.time_end * 60):
		var hour: int = int(exact_minute / 60.0)
		
		# Assume 0% if hour isnt defined in seed
		var arrival_pct: float = arrival_seed.get(hour, 0.0)
		
		# Stop arrivals after closing, this might be uneeded also
		if exact_minute >= %TimeManager.time_close * 60:
			arrival_pct = 0.0
			
		var total_hour_agents: float = float(total_daily_agents) * arrival_pct
		var expected_minute_agents: float = total_hour_agents / 60.0
		
		schedule[exact_minute] = _get_poisson(expected_minute_agents)

	if perfect_arrivals:
		var actual_total: int = 0
		for count: int in schedule.values():
			actual_total += count
			
		var diff: int = actual_total - total_daily_agents
		
		# randomly remove excess guests from minutes that have guests
		while diff > 0:
			var valid_keys: Array = schedule.keys().filter(func(k: int) -> bool: return schedule[k] > 0)
			if valid_keys.is_empty():
				break
				
			var random_key: int = valid_keys.pick_random()
			schedule[random_key] -= 1
			diff -= 1
			
		# Add missing guests randomly to valid minute in schedule
		while diff < 0:
			var all_keys: Array = schedule.keys()
			if all_keys.is_empty():
				break
				
			var random_key: int = all_keys.pick_random()
			schedule[random_key] += 1
			diff += 1
	
	return schedule


## Knuth's algorithm
func _get_poisson(lambda_val: float) -> int:
	if lambda_val <= 0.0:
		return 0
		
	var limit: float = exp(-lambda_val)
	var k: int = 0
	var p: float = 1.0
	
	while p > limit:
		k += 1
		p *= randf()
		
	return k - 1
	
	

func create_agent() -> void:
	var new_agent: Agent = agent_prefab.instantiate()
	agent_parent.add_child(new_agent)
	new_agent.initialize(current_id, (%AgentProfiles as AgentProfileManager).random_agent_profile())
	in_park_agents.append(new_agent)
	new_agent.position = Vector3.ZERO
	
	current_id += 1

	
func _ready() -> void:
	entry_minute_distribution = generate_arrival_schedule(true)
	
func _tick(minute, delta) -> void:
	# Spawn agents
	if minute in entry_minute_distribution:
		for i in range(entry_minute_distribution[minute]):
			create_agent()
