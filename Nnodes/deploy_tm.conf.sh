#!/bin/bash

#### Configuration options #############################################

# One Docker container will be configured for each IP address in $ips
current_node=1
ips=

if [ "$1" != "" ]
then
  current_node=$1
fi
if [ "$2" != "" ]
then
  ips=$@
fi

# Docker image name
image=yopoo/quorum

uid=`id -u`
gid=`id -g`
pwd=`pwd`


#### Make node list for tm.conf ########################################

nodelist=
n=1


# echo 'ips: '${!ips[@]}

for ip in ${ips[*]}
do
    echo $n', ip:'$ip
    if [[ $n -gt 1 ]]
    then
      sep=`[[ $n != 2 ]] && echo ","`
      nodelist=${nodelist}${sep}'"http://'${ip}':9000/"'
    fi
    let n++
done


# echo 'ips: '${!ips[@]}
# echo 'myip2: '${ips[2]}
# echo 'myip3: '${ips[3]}

#### Complete each node's configuration ################################

echo '[4] Creating Quorum keys and finishing configuration.'

qd=qdata_0

# echo $((current_node))
# echo ${ips[2]}
# echo 'myip2: '${ips[$current_node]}

n=0
for ip in ${ips[*]}
do
    if [[ $n -eq $current_node ]]
    then
      echo 'myip: '$ip
      cat templates/tm.conf \
        | sed s/_NODEIP_/$ip/g \
        | sed s%_NODELIST_%$nodelist%g \
              > $qd/tm.conf
    fi
    let n++
done

# cat templates/tm.conf \
#     | sed s/_NODEIP_/${ips[$current_node]}/g \
#     | sed s%_NODELIST_%$nodelist%g \
#           > $qd/tm.conf

cp genesis.json $qd/genesis.json
# cp static-nodes.json $qd/dd/static-nodes.json

# Generate Quorum-related keys (used by Constellation)
docker run -u $uid:$gid -v $pwd/$qd:/qdata $image /usr/local/bin/constellation-node  --generatekeys=/qdata/keys/tm < /dev/null > /dev/null
docker run -u $uid:$gid -v $pwd/$qd:/qdata $image /usr/local/bin/constellation-node  --generatekeys=/qdata/keys/tma < /dev/null > /dev/null
# echo 'Node '$n' public key: '`cat $qd/keys/tm.pub`

if [ $current_node -eq 1 ]; then
  cp $qd/dd/static-nodes.json $qd/dd/permissioned-nodes.json
  cp templates/start-node-permission.sh $qd/start-node.sh
  echo 'Node '$n': permissioned' 
else
  cp templates/start-node.sh $qd/start-node.sh
fi
chmod 755 $qd/start-node.sh

echo 'Done!'
