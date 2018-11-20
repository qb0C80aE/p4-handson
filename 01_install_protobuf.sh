#!/bin/bash
mkdir ~/work # 以降、ここで作業
cd ~/work
git clone https://github.com/google/protobuf.git
cd protobuf
git checkout v3.2.0 # README推奨のバージョン
./autogen.sh
./configure
make
sudo make install
sudo ldconfig
