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

# Warning about california
You may find strings referencing a "california-themed theme park in the already california-themed california", or worse,
a "florida-themed theme park in the already florida-themed florida". PLEASE DISRGARD. **Be assured this project is about
and only about a certain magical Safari themed theme park.**