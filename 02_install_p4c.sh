#!/bin/bash
cd ~/work
git clone --recursive https://github.com/p4lang/p4c.git 
cd p4c
./bootstrap.sh
cd build
cmake .. -DENABLE_EBPF=OFF # 今回使わない(準備しておかないとcmakeでエラーになる)のでdisableにする。
make # coreたくさんあれば-jX指定すると早く終わる。
sudo make install
