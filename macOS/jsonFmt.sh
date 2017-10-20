#/bin/bash

log=$1
ltype=$2
echo "---***$ltype***---"
json=$(echo ${log##*=})
echo $json | jq
echo "---***$ltype***---"
