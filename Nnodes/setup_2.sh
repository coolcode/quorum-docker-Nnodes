#!/bin/bash
./setup_1.sh 7 0
./setup_1.sh 3 7

number_of_node=10
echo 'All public keys:'
n=1
while [ $n -le $number_of_node ]
do
  n=$(( $n + 1 )) 
  # begins with 172.13.0.2
  qd=qdata_$n
  echo '"'`cat $qd/keys/tm.pub`'",'
done

rm -rf genesis.json static-nodes.json


#### Create the docker-compose file ####################################

cat > docker-compose.yml <<EOF
version: '2'
services:
EOF

n=1
while [ $n -le $number_of_node ]
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