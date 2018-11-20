#!/bin/bash
sudo ip netns add host1
sudo ip netns add host2
sudo ip link add v11 type veth peer name v12
sudo ip link add v21 type veth peer name v22
sudo ip link set dev v11 addr 10:54:ff:99:00:11
sudo ip link set dev v12 addr 10:54:ff:99:00:12
sudo ip link set dev v21 addr 10:54:ff:99:00:21
sudo ip link set dev v22 addr 10:54:ff:99:00:22
sudo ip link set v12 netns host1
sudo ip link set v22 netns host2
sudo ip link set v11 up
sudo ip link set v21 up
sudo ip netns exec host1 ip link set v12 up
sudo ip netns exec host2 ip link set v22 up
sudo ip netns exec host1 ip link set lo up
sudo ip netns exec host2 ip link set lo up
sudo ip netns exec host1 ip addr add 10.0.0.1/24 dev v12
sudo ip netns exec host2 ip addr add 10.0.1.1/24 dev v22 
sudo ip netns exec host1 ip route add 10.0.1.0/24 via 10.0.0.254
sudo ip netns exec host2 ip route add 10.0.0.0/24 via 10.0.1.254
