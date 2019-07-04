#!/bin/bash
#### Configuration options #############################################

# One Docker container will be configured for each IP address in $ips
subnet="172.13.0.0/24"
number_of_node=$1
offest=$2
begin_index=$(( $2 + 1 )) 
echo 'parameters: '$number_of_node' '$offest' '$begin_index'. '
#ips=("172.13.0.15" "172.13.0.2" "172.13.0.3")
ips=()
x=$begin_index
while [ $x -le $number_of_node ]
do
  x=$(( $x + 1 )) 
  # begins with 172.13.0.2
  ips+=("172.13.0.$x")
done

# Docker image name
image=yopoo/quorum

########################################################################

nnodes=${#ips[@]}

#echo '[1] '$nnodes' nodes.'

if [[ $nnodes < 02 ]]
then
    echo "ERROR: There must be more than one node IP address."
    exit 1
fi
   
./cleanup.sh

uid=`id -u`
gid=`id -g`
pwd=`pwd`

#### Create directories for each node's configuration ##################

echo '[1] Configuring for '$nnodes' nodes.'

#exit 1

n=$begin_index 
for ip in ${ips[*]}
do
    qd=qdata_$n
    mkdir -p $qd/{logs,keys}
    mkdir -p $qd/dd/geth

    let n++
done


#### Make static-nodes.json and store keys #############################

echo '[2] Creating Enodes and static-nodes.json.'

echo "[" > static-nodes.json
n=$begin_index
for ip in ${ips[*]}
do
    qd=qdata_$n

    # Generate the node's Enode and key
    enode=`docker run -u $uid:$gid -v $pwd/$qd:/qdata $image /usr/local/bin/bootnode -genkey /qdata/dd/nodekey`
    enode=`docker run -u $uid:$gid -v $pwd/$qd:/qdata $image /usr/local/bin/bootnode -nodekey /qdata/dd/nodekey -writeaddress`

    # Add the enode to static-nodes.json
    echo ' '$enode'@'$ip' '
    sep=`[[ $n !=  $nnodes ]] && echo ","`
    echo '  "enode://'$enode'@'$ip':30303?discport=0&raftport=50400"'$sep >> static-nodes.json

    let n++
done
echo "]" >> static-nodes.json


#### Create accounts, keys and genesis.json file #######################

echo '[3] Creating Ether accounts and genesis.json.'

cat > genesis.json <<EOF
{
  "alloc": {
EOF

n=$begin_index
for ip in ${ips[*]}
do
    qd=qdata_$n

    # Generate an Ether account for the node
    touch $qd/passwords.txt
    account=`docker run -u $uid:$gid -v $pwd/$qd:/qdata $image /usr/local/bin/geth --datadir=/qdata/dd --password /qdata/passwords.txt account new | cut -c 11-50`

    # Add the account to the genesis block so it has some Ether at start-up
    sep=`[[ $n != $nnodes ]] && echo ","`
    cat >> genesis.json <<EOF
    "0x${account}": {
      "balance": "1000000000000000000000000000"
    }${sep}
EOF

    let n++
done

cat >> genesis.json <<EOF
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


#### Make node list for tm.conf ########################################

nodelist=
n=$begin_index
for ip in ${ips[*]}
do
    sep=`[[ $ip != ${ips[0]} ]] && echo ","`
    nodelist=${nodelist}${sep}'"http://'${ip}':9000/"'
    let n++
done


#### Complete each node's configuration ################################

echo '[4] Creating Quorum keys and finishing configuration.'

n=$begin_index
for ip in ${ips[*]}
do
    qd=qdata_$n

    cat templates/tm.conf \
        | sed s/_NODEIP_/${ips[$((n-1))]}/g \
        | sed s%_NODELIST_%$nodelist%g \
              > $qd/tm.conf

    cp genesis.json $qd/genesis.json
    cp static-nodes.json $qd/dd/static-nodes.json

    # Generate Quorum-related keys (used by Constellation)
    docker run -u $uid:$gid -v $pwd/$qd:/qdata $image /usr/local/bin/constellation-node  --generatekeys=/qdata/keys/tm < /dev/null > /dev/null
    docker run -u $uid:$gid -v $pwd/$qd:/qdata $image /usr/local/bin/constellation-node  --generatekeys=/qdata/keys/tma < /dev/null > /dev/null
    # echo 'Node '$n' public key: '`cat $qd/keys/tm.pub`

    if [ $n -eq 1 ]; then
      cp static-nodes.json $qd/dd/permissioned-nodes.json
      cp templates/start-node-permission.sh $qd/start-node.sh
      echo 'Node '$n': permissioned' 
    else
      cp templates/start-node.sh $qd/start-node.sh
    fi
    chmod 755 $qd/start-node.sh

    let n++
done

