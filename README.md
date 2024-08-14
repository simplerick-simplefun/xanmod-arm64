Credit: zijiren233/xanmod-arm64

Modification:

Add auto release to github actions: checks for new xanmod release, and build&release new kernel .deb files automatically.

Tested on:

Oracle OCI Ampere A1 Compute instances / Ubuntu 22.04.4 LTS

Installation script (Debian):

```
#!/usr/bin/bash

sudo apt install jq wget -y

sudo rm -rf ./tempxmod
mkdir ./tempxmod
cd ./tempxmod

xmod_latest_version="$(wget -qO- https://api.github.com/repos/simplerick-simplefun/xanmod-arm64/releases | jq '.[0].assets')"

wget "$(echo $xmod_latest_version | jq -r '.[0].browser_download_url')"
wget "$(echo $xmod_latest_version | jq -r '.[1].browser_download_url')"
wget "$(echo $xmod_latest_version | jq -r '.[2].browser_download_url')"

sudo dpkg -i *.deb

cd ..
rm -rf ./tempxmod

sudo apt autoremove -y
sudo reboot
```
