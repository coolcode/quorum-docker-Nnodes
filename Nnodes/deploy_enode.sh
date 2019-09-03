#!/bin/bash

#### Configuration options #############################################

# One Docker container will be configured for each IP address in $ips
current_node=1
ip=

if [ "$1" != "" ]
then
  current_node=$1
fi
if [ "$2" != "" ]
then
  ip=$2
fi


# Docker image name
image=yopoo/quorum

########################################################################
   
./cleanup.sh

uid=`id -u`
gid=`id -g`
pwd=`pwd`

#### Create directories for each node's configuration ##################

echo '[1] Configuring for node '$current_node'.'

qd=qdata_0
mkdir -p $qd/{logs,keys}
mkdir -p $qd/dd/geth


#### Make static-nodes.json and store keys #############################

echo '[2] Creating Enodes and static-nodes.json.'

# Generate the node's Enode and key
enode=`docker run -u $uid:$gid -v $pwd/$qd:/qdata $image /usr/local/bin/bootnode -genkey /qdata/dd/nodekey`
enode=`docker run -u $uid:$gid -v $pwd/$qd:/qdata $image /usr/local/bin/bootnode -nodekey /qdata/dd/nodekey -writeaddress`

# Add the enode to static-nodes.json
echo $enode'@'$ip

#echo '  "enode://'$enode'@'$ip':30303?discport=0&raftport=50400"' >> static-nodes.json
# save enode
echo $enode > 'enode.txt'


#### Create accounts, keys and genesis.json file #######################

echo '[3] Creating Ether accounts and genesis.json.'

# Generate an Ether account for the node
touch $qd/passwords.txt
account=`docker run -u $uid:$gid -v $pwd/$qd:/qdata $image /usr/local/bin/geth --datadir=/qdata/dd --password /qdata/passwords.txt account new | cut -c 11-50`

# Add the account to the genesis block so it has some Ether at start-up
cat > genesis.json <<EOF
{
  "alloc": {
    "0x${account}": {
      "balance": "1000000000000000000000000000"
    }
  },
  "coinbase": "0x0000000000000000000000000000000000000000",
  "config": {
    "byzantiumBlock": 1,
    "chainId": 10,
    "eip150Block": 1,
    "eip155Block": 0,
    "eip150Hash": "0x0000000000000000000000000000000000000000000000000000000000000000",
    "eip158Block": 1,
    "isQuorum":true
  },
  "difficulty": "0x0",
  "extraData": "0x",
  "gasLimit": "0x2FEFD800",
  "mixhash": "0x00000000000000000000000000000000000000647572616c65787365646c6578",
  "nonce": "0x0",
  "parentHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "timestamp": "0x00"
}
EOF


#### Create the docker-compose file ####################################

cat > docker-compose.yml <<EOF
version: '2'
services:
  node_1:
    image: $image
    volumes:
      - './$qd:/qdata'
    ports:
      - 22001:8545
      - 9000:9000
      - 30303:30303
      - 50400:50400
    user: '$uid:$gid'
EOF

echo 'Done!'
