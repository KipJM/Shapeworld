extends Node
class_name RideManager

@export var ride_popularity: Dictionary[Ride, float]


func get_random_ride() -> Ride:
	return WeightedRandom.get_weighted_random(ride_popularity)
	
func filter_rides(predicate: Callable) -> Dictionary[Ride, float]:
	var filtered_rides: Dictionary = {}
	for ride in ride_popularity:
		if predicate.call(ride_popularity[ride]):
			filtered_rides[ride] = ride_popularity[ride]
	return filtered_rides

func get_random_filtered_ride(predicate: Callable) -> Ride:
	return WeightedRandom.get_weighted_random(filter_rides(predicate))
