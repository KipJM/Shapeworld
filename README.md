# Shapeworld!
![shapeworld.png](.promo/shapeworld.png)
A 3D realtime computer simulation of park guest agents in a certain industry leader's Safari-themed theme park.

Inspired by Defunctland's [shapeland](https://github.com/TouringPlans/shapeland), this project uses Godot to create a 
realtime simulation and visualization of every single park guest in a day. This project adds walk time into consideration,
along with the ability to check wait times and obtain fastpasses online, plus fixes a bug with shapeland's fastpass implementation.

Please not that unlike shapeland, this project has not been tuned to match real-world data.

Please go watch [Disney's FastPass: A Complicated History](https://www.youtube.com/watch?v=9yjZpBq1XBE).

---
3D map data from OpenStreetMap, [copyright OpenStreetMap and Contributors](https://www.openstreetmap.org/copyright).

# Support
> **If you liked this project, considering buying me a ~~coffee~~ milktea!**
>
> [![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://kip.gay/support)\
> (https://kip.gay/support)

# Running
Shapeworld is designed to be ran in-editor since most configurations are too complicated to be changed through in-game UI.
Clone this project to your computer, and edit it with [Godot Editor 4.6.2 .NET](https://godotengine.org/download) or later.
> This project uses C#, make sure to download the .NET version.

This project has been designed with performance in mind (agents are rendered through GPU instancing, pathfinding data is cached), 
however performance heavily depends on how many agents are in the park plus your computer hardware.\
Disabling activity roaming can  dramatically improve performance, but this also influences agent behavior.

# Demo
### **For evaluation, I'm also providing a demo build of the executable with some preset simulation parameters. You can find it in releases.**

Specifically, high-speed simulation (path sampling) is on, there are 2500 agents max, and activity roaming is on.

Use WASD / Controller to move around, check the help info on the top left.

## License
This project is licensed under [GNU General Public License v3.](https://www.gnu.org/licenses/gpl-3.0.en.html)

You are not allowed to use this project to train "Generative AI" or "LLM" machine learning models.

## Features that this has but shapeland doesn't
### realtime 3D visualization
yeah

Agents are rendered through GPU instancing.

### **Walking and pathfinding**
![pathfinding.png](.promo/pathfinding.png)
- Agents spend time physically walking from ride to ride
- Agents will consider walking time to ride and back if they have a fastpass reservation
- (optional) agents will walk to a random point in the park to do activities 

Agents automatically pathfind through navmeshes to reach their destination. For slower simulation speeds, the agents
walk physically with obstacle avoidance to prevent bumping into other guests. For fast simulations, agents use path sampling
to move between waypoints, increasing performance.

Walktimes are considered in agents' behavior, such as planning around fastpasses. Walking has a backup timer, so that if
the agent can't make it to the target in time (estimated based on distance and walking speed), they'll be teleported.

### Online wait times checking and online fastpasses
Before committing and walking to the ride, the agent can check the wait times beforehands. If above balking point, the agent
either choose another ride to go to, or get a fastpass online without having to physically go to the ride. After getting the 
fp, the agent will immediately choose another ride to go to.

The availability of online features can be controlled, via both:
- Ride:
  - A ride can choose to support any set of these three: physical fastpass, online wait times checking, online fastpasses
- Agent:
  - Based on percentages, it will be randomly decided if an agent knows about online wait times or fastpasses features. If an agent knows about both, they automatically know how to obtain online fastpasses too.

### A different (slightly better) fastpass algorithm
See below.

### Agents have a more complex decision making process

#### plus some other stuff maybe
#### maybe more bugs than shapeland

## Features that shapeland has but this doesn't
- child/adult eligibility. All rides are assumed to be all ages.
- FastPass+ support out of the box: While agents are allowed to have 3 fastpasses at the same time by default, they will only get fastpasses if the standby is over their balking point. Agents are also not encouraged to get fastpasses ASAP unlike actual FP+
- There are less data collection/visualization features, such as a lack of final summary / graphs. However data is indeed stored within the managers, and it should be trivial to write some code to retrieve the data into csv based on your interests.

# Warning about fastpass algorithm
The fastpass algorithm is ported (with changes) from Defunctland's shapeland project. However shapeland
implements fastpass return window calculation in a way that does not match _the industry leader's_ real world implementation **at all.**

This project implements a slightly better algorithm that basically uses the standby wait time as the return window. However all the code
that's needed for shapeland's implementation are still present in the files. You are encouraged to change them to your needs.

> (There is a chance I grossly misunderstood how shapeland implements fastpass, which would make this whole section
> grossly incorrect. If so, please tell me through creating an issue or emailing me at yourfastpassisbroken@kip.gay)

Shapeland and shapeworld assigns the time window by estimating how much time it would take to queue through the fastpass
queue. **THIS IS ENTIRELY INCORRECT.** As stated by Defunctland and in the project, _the industry leader_ typically uses a 80-20 ratio
to feed in fastpass guests. That means for each 2 standby guest, 8 fp guests are allowed on the ride. The purpose of this
ratio is so that when many guests come to redeem their fp at the same time, there won't be a massive **physical** fp queue.

The shapeland project confuses the **physical** fp queue with the fastpass **virtual** queue, the latter should be the one
dictating the return time window. Instead, for a guest in shapeland getting a fastpass, the return window they're given
would be the time it takes to get on the ride if they enter the **physical** fp queue right now. Since fp queues get an
agressive 80% split plus it's typically empty (proof: just check the fast lane at your local theme park), it's almost
always faster to get on a ride just by getting a fastpass and almost immediately redeem it.

From my limited research, how the industry leader implements fastpass is: Through analysis of past crowd data, they assign a
return window where the ride has relative low ridership, therefore balancing the load on the ride over the day.\
Maybe it's done another way. What's certain is that it should be highly improbable to get a fastpass that's
faster than the standby queue (okay I got it once on the Liberty Belle but that's a long time ago and I forgot how I did it)

Since I don't have the crowd data, and as I said this project is not tuned to fit any real world crowd data, I just made the fp
return window use the current standby time. That should be at least the most fair. Also, in shapeland, the fp physical queue
and virtual queue are not separated, in shapeworld it is. Please excuse the messy variable names, the fp system went 
through many iterations (as you can tell).

# Architecture
Unlike shapeland, simulation configuration is split into many managers within shapeworld. Also unlike shapeland's data-driven simulation,
shapeworld create individual agents via OOP (honestly should've used ECS for this project) which operates independently.
While most events are driven by the minute tick, walking is simulated every real-world frame.

Tooltips include important info.\
Names of nodes are important.

Dictionaries in the format of [Profile, float] are typically probability distributions. Except for arrival seed, the densities do not have to add up to one.

- AgentManager: Agent spawning
- AgentProfiles: Global agent settings
  - children: possible agent profiles
- renderer_agent: GPU Instanced agent rendering
- Rides: Manage ride popularity
  - children: rides. Their position determine where agents will go to.
- Activities: basically the same thing
- TimeManager: when does the day start, when does the park close, when does the simulation end
  - IMPORTANT: minute delta: how many real world seconds is one simulated minute,
    - when delta is too small it will auto switch to high speed simulation mode

# Warning about california
You may find strings referencing a "california-themed theme park in the already california-themed california", or worse,
a "florida-themed theme park in the already florida-themed florida". PLEASE DISRGARD. **Be assured this project is about
and only about a certain magical Safari themed theme park.**