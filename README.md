# SixtCarSummoner
## What it does
We developed an App that gives a nice interface where the user can type in their start location and destination. The user then receives the position of the nearest (by driving time) RoboTaxi and the option to order the vehicle. If they decide to order the vehicle, an estimated time to arrival (ETA) is displayed.
Backend we have developed a controller that efficiently decides which car picks up the user and calculates the ETA. We also integrated the sixt API into our server.
## How we built it
We used a python server to integrate the SIXT and the googleMaps API. The server functions as middleware between the App and the APIs by providing necessary data. The Swift App integrates the AppleMaps API.
## Challenges we ran into
It was quite a challenge to make our python server communicate with our Swift app, especially to make our app handle json data, apparently swift is not a fan of the .json format!
Also the lack of more time was quite a challenge.
## Accomplishments that we're proud of
Connecting our backend server with our App was very time intensive, but we are also very proud that we got it to work.
## What we learned
Sleep is more important than you might think 😉
We all learned different stuff that we didnt know before.
## What's next for Sixt Car Summoner
We have plenty of more ideas, for example
- proper Spotify integration
- pre heating/cooling option after you ordered a vehicle
- division of munich in virtual districts in order to spread the non-booked roboTaxis more equally

...and much more but unfortunately we didnt have enough time 😦
