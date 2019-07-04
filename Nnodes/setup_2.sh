#!/bin/bash
number_of_node=$1
subnet=$2
uid=`id -u`
gid=`id -g`
image=yopoo/quorum
echo 'All nodes: http://localhost:22001-'$(($number_of_node+22000))''

ips=()
x=1
while [ $x -le $number_of_node ]
do
  echo '"http://localhost:'$(($x+22000))'",'
  x=$(( $x + 1 ))
  # begins with 172.13.0.2
  ip="172.13.0.$x"
  ips+=($ip)
done

echo 'All public keys:'
n=1
while [ $n -le $number_of_node ]
do
  qd=qdata_$n
  echo '"'`cat $qd/keys/tm.pub`'",'
  let n++
done

rm -rf genesis.json static-nodes.json


#### Create the docker-compose file ####################################

cat > docker-compose.yml <<EOF
version: '2'
services:
EOF

n=1
for ip in ${ips[*]}
do
    qd=qdata_$n

    cat >> docker-compose.yml <<EOF
  node_$n:
    image: $image
    volumes:
      - './$qd:/qdata'
    networks:
      quorum_net:
        ipv4_address: '$ip'
    ports:
      - $((n+22000)):8545
    user: '$uid:$gid'
EOF

    let n++
done

cat >> docker-compose.yml <<EOF

networks:
  quorum_net:
    driver: bridge
    ipam:
      driver: default
      config:
      - subnet: $subnet
EOF


#### Create pre-populated contracts ####################################

# Private contract - insert Node 2 as the recipient
cat templates/contract_pri.js \
    | sed s:_NODEKEY_:`cat qdata_2/keys/tm.pub`:g \
          > contract_pri.js

# Public contract - no change required
cp templates/contract_pub.js ./
echo 'Done!'