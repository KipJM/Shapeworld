extends Node
class_name ActivityManager

@export var activity_popularity: Dictionary[Activity, float]

func get_random_activity() -> Activity:
	return WeightedRandom.get_weighted_random(activity_popularity)

func filter_activities(predicate: Callable) -> Dictionary[Activity, float]:
	var filtered_activity: Dictionary = {}
	for act in activity_popularity:
		if predicate.call(activity_popularity[act]):
			filtered_activity[act] = activity_popularity[act]
			
	return filtered_activity
	
func get_random_filtered_activity(predicate: Callable) -> Activity:
	return WeightedRandom.get_weighted_random(filter_activities(predicate))
