# spotify-auto-like

This script addresses a common frustration among Spotify users by automating the process of adding/liking individual songs when an album is added to the library. That way, you can shuffle your whole library through the "Liked Songs" playlist.

This script is fully functional, but soon I'll release cross-platform binaries to make it easier to execute without requiring any external dependencies. 

## Usage
```
make bash
dart pub get
dart run
```

An URL will appear, you will need to click on it to authorize the application which only needs these two permissions from your account:
- read your library *(to get a list of the currently saved tracks in order to avoid making useless requests)*
- modify your library *(to save tracks that are not in this playlist yet)*
