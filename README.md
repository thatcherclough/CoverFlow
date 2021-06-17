# CoverFlow
CoverFlow is an iOS app that syncs album covers with Phillis Hue lights.

## Demo
[![CoverFlow demo](http://img.youtube.com/vi/OSRmeijsdT8/0.jpg)](http://www.youtube.com/watch?v=OSRmeijsdT8 "CoverFlow demo")

## How it works
CoverFlow uses [ColorThief](https://github.com/yamoridon/ColorThiefSwift) to find the dominant colors in the current playing song's album cover and creates color loops using these colors. The Phillips Hue smart lights then run these color loops. 

CoverFlow is compatible with both Apple Music and Spotify.

Further development information:

CoverFlow uses a custom python API that can be found in the "api" folder. More information about this API can be found in its [documentation](api/README.md).
While the Xcode project will compile, it will not run properly because an API base url, a Spotify client ID, and a Spotify redirect uri are required when running ``pod install``. 

## Installation
CoverFlow can be installed from the [App Store](https://apps.apple.com/us/app/coverflow/id1537471277).

## Credits
- [@bermudalckt](https://twitter.com/bermudalckt) for advice and help with [ColorThief](https://github.com/yamoridon/ColorThiefSwift).
- [Aryan Nambiar](https://twitter.com/ifisq) for help with implementing Spotify.
## License
[MIT](https://choosealicense.com/licenses/mit/)

Copyright 2021 © Thatcher Clough.
