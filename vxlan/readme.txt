================================================= TEST2 =================================
OUTCOME CONFIG TEST: OK
 ------------------------10.0.0.0/24-------------------------
|       Node 1                             Node 2            |
|10.0.0.10/24 (eth0)                  10.0.0.20/24 (eth0)    |
|172.16.0.1/24 (vxlan0) <---VXLAN---> 172.16.0.2/24 (vxlan0) |
-------------------------------------------------------------
vm1:
ip link add vxlan0 type vxlan id 10 dev eth0 dstport 0
bridge fdb add 00:00:00:00:00:00 dev vxlan0 dst 10.0.0.20
ip addr add 172.16.0.1/24 dev vxlan0
ip link set up dev vxlan0

vm2:
ip link add vxlan0 type vxlan id 10 dev eth0 dstport 0
bridge fdb add 00:00:00:00:00:00 dev vxlan0 dst 10.0.0.10
ip addr add 172.16.0.2/24 dev vxlan0
ip link set up dev vxlan0



root@vm1:~# bridge fdb show dev vxlan0
00:00:00:00:00:00 dst 10.0.0.20 self permanent
1a:a5:da:3e:49:1c dst 10.0.0.20 self

root@vm1:~# ip -d link show vxlan0
6: vxlan0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/ether 36:11:f1:3d:5f:b1 brd ff:ff:ff:ff:ff:ff promiscuity 0 minmtu 68 maxmtu 65535
    vxlan id 10 dev eth0 srcport 0 0 dstport 8472 ttl auto ageing 300 udpcsum noudp6zerocsumtx noudp6zerocsumrx addrgenmode eui64 numtxqueues 1 numrxqueues 1 gso_max_size 62780 gso_max_segs 65535


root@vm2:~# bridge fdb show dev vxlan0
00:00:00:00:00:00 dst 10.0.0.10 self permanent
36:11:f1:3d:5f:b1 dst 10.0.0.10 self

root@vm2:~# ip -d link show vxlan0
5: vxlan0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/ether 1a:a5:da:3e:49:1c brd ff:ff:ff:ff:ff:ff promiscuity 0 minmtu 68 maxmtu 65535
    vxlan id 10 dev eth0 srcport 0 0 dstport 8472 ttl auto ageing 300 udpcsum noudp6zerocsumtx noudp6zerocsumrx addrgenmode eui64 numtxqueues 1 numrxqueues 1 gso_max_size 62780 gso_max_segs 65535




*** delete vxlan0 device:
ip link delete vxlan0



================================================= TEST2 =================================
Custom destination port
OUTCOME CONFIG TEST: OK

vm1:
ip link add vxlan0 type vxlan id 10 dev eth0 dstport 888
bridge fdb add 00:00:00:00:00:00 dev vxlan0 dst 10.0.0.20
ip addr add 172.16.0.1/24 dev vxlan0
ip link set up dev vxlan0

vm2:
ip link add vxlan0 type vxlan id 10 dev eth0 dstport 888
bridge fdb add 00:00:00:00:00:00 dev vxlan0 dst 10.0.0.10
ip addr add 172.16.0.2/24 dev vxlan0
ip link set up dev vxlan0

