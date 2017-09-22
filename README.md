# [under construction] Play My Music

### Play My Music is a simple player for local files designed for [elementary OS](https://elementary.io)

![screenshot](Screenshot.png)

TODO:
* Playlists
* DBUS
* Media keys

## Install from Github.

As first you need elementary SDK
```
sudo apt install elementary-sdk
```

Clone repository and change directory
```
git clone https://github.com/artemanufrij/playmymusic.git
cd playmymusic
```

Create **build** folder, compile and start application
```
mkdir build
cd build
cmake -DCMAKE_INSTALL_PREFIX=/usr ..
make
./src/com.github.artemanufrij.playmymusic
```

(optional) Install PlayMyMusic on your system
```
sudo make install
```
