<div>
  <h1 align="center">Melody</h1>
  <h3 align="center"><img src="data/icons/64/com.github.artemanufrij.playmymusic.svg"/><br>A music player for listening to local music files, online radios, and Audio CD's</h3>
  <p align="center">Designed for <a href="https://elementary.io">elementary OS</a></p>
</div>

[![Build Status](https://travis-ci.org/artemanufrij/playmymusic.svg?branch=master)](https://travis-ci.org/artemanufrij/playmymusic)

### Donate
<a href="https://www.paypal.me/ArtemAnufrij">PayPal</a> | <a href="https://liberapay.com/Artem/donate">LiberaPay</a> | <a href="https://www.patreon.com/ArtemAnufrij">Patreon</a>

<p align="center">
  <a href="https://appcenter.elementary.io/com.github.artemanufrij.playmymusic">
    <img src="https://appcenter.elementary.io/badge.svg" alt="Get it on AppCenter">
  </a>
  <a href="https://flathub.org/apps/details/com.github.artemanufrij.playmymusic">
    <img src="https://flathub.org/assets/badges/flathub-badge-i-en.svg" width="150px" alt="Download On Flathub">
  </a>
</p>

<br/>

![screenshot](screenshots/Screenshot.png)
![screenshot](screenshots/Screenshot_Artists.png)
![screenshot](screenshots/Screenshot_Tracks.png)

## Install from Flatpak
Melody on Flathub: https://flathub.org/apps/details/com.github.artemanufrij.playmymusic

Install
```
flatpak install flathub com.github.artemanufrij.playmymusic
```

Run
```
flatpak run com.github.artemanufrij.playmymusic
```

## Install from Github.

As first you need elementary SDK
```
sudo apt install elementary-sdk
```

Install dependencies
```
sudo apt install libsoup2.4-dev libsqlite3-dev libgstreamer-plugins-base1.0-dev libtagc0-dev
```

Clone repository and change directory
```
git clone https://github.com/artemanufrij/playmymusic.git
cd playmymusic
```

Compile, install and start Melody on your system
```
meson build --prefix=/usr
cd build
sudo ninja install
com.github.artemanufrij.playmymusic
```
