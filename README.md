# CoverFlow
CoverFlow is an iOS app that syncs album covers with Phillis Hue lights.

## Demo
[![CoverFlow demo](http://img.youtube.com/vi/OSRmeijsdT8/0.jpg)](http://www.youtube.com/watch?v=OSRmeijsdT8 "CoverFlow demo")

## How it works
CoverFlow uses [ColorThief](https://github.com/yamoridon/ColorThiefSwift) to find the dominant colors in the current playing song's album cover and creates color loops using these colors. The Phillips Hue smart lights then run these color loops. 

CoverFlow is compatible with both Apple Music and Spotify.

Note: While this project will compile, it will not run properly because an Apple Music API key, a Spotify Client ID, and a Spotify Client ID secret are required when running ``pod install``. 
Instruction for obtaining the Apple Music API key can be found [here](https://developer.apple.com/documentation/applemusicapi/getting_keys_and_creating_tokens). 
In addition to following those instructions, I used [this python program](https://github.com/pelauimagineering/apple-music-token-generator) to generate the key after gathering the necessary information.
## Installation
CoverFlow can be installed from the [App Store](https://apps.apple.com/us/app/coverflow/id1537471277).

## Credits
- [@bermudalckt](https://twitter.com/bermudalckt) for advice and help with [ColorThief](https://github.com/yamoridon/ColorThiefSwift).
- [Aryan Nambiar](https://twitter.com/ifisq) for help with implementing Spotify.
## License
[MIT](https://choosealicense.com/licenses/mit/)

Copyright 2020 © Thatcher Clough.
