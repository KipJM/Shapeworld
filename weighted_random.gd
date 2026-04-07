class_name WeightedRandom

# Selects a random key from a dictionary based on its value (weight)
static func get_weighted_random(weights_dict: Dictionary) -> Variant:
	var total_weight: float = 0.0
	
	# 1. Calculate the total weight
	for weight in weights_dict.values():
		total_weight += weight
		
	# 2. Pick a random number between 0 and the total weight
	# Note: Use rand_range() instead of randf_range() if you are on Godot 3
	var random_val: float = randf_range(0.0, total_weight)
	
	# 3. Iterate to find which item the random number landed on
	var current_weight: float = 0.0
	for key in weights_dict.keys():
		current_weight += weights_dict[key]
		if random_val <= current_weight:
			return key
			
	return null
