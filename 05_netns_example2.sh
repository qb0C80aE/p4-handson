#!/bin/bash
sudo ip netns add host3
sudo ip netns add host4
sudo ip link add v31 type veth peer name v32
sudo ip link add v41 type veth peer name v42
sudo ip link set dev v31 addr 10:54:ff:99:03:31
sudo ip link set dev v32 addr 10:54:ff:99:03:32
sudo ip link set dev v41 addr 10:54:ff:99:04:41
sudo ip link set dev v42 addr 10:54:ff:99:04:42
sudo ip link set v32 netns host3
sudo ip link set v42 netns host4
sudo ip link set v31 up
sudo ip link set v41 up
sudo ip netns exec host3 ip link set v32 up
sudo ip netns exec host4 ip link set v42 up
sudo ip netns exec host3 ip link set lo up
sudo ip netns exec host4 ip link set lo up
sudo ip netns exec host3 ip addr add 10.0.0.1/24 dev v32
sudo ip netns exec host4 ip addr add 10.0.1.1/24 dev v42 
sudo ip netns exec host3 ip route add 10.0.1.0/24 via 10.0.0.254
sudo ip netns exec host4 ip route add 10.0.0.0/24 via 10.0.1.254
