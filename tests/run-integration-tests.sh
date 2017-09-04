#!/bin/bash

# Exit immediately if command returns non-zero status code
set -e

if [ -z "$1" ]; then
  echo "No given instance of JBoss EAP ! Exiting..."
  exit 1
fi

appurl="$1"

function runtest() {
  url="$1"
  expected="$2"
  i=0
  while [ "$i" -lt 10 ] && ret="$(curl -s -o /dev/null -b cookies.txt -c cookies.txt -w "%{http_code}" "$url")" && [ "$ret" != "$expected" ]; do
    echo "$url: Got a '$ret' HTTP Status Code. An OpenShift deployment may be pending ? Sleeping for a while and retrying..."
    sleep 10
    let "i=i+1"
  done
  if [ "$ret" != "$expected" ]; then
    echo "$url: Got HTTP Status code '$ret' instead of a '$expected' Status code."
    exit 1
  fi
}

runtest "$appurl/" 200
runtest "$appurl/ws/demo/name" 200
runtest "$appurl/ws/demo/log/info" 200
runtest "$appurl/blabla" 404

echo "Successfully passed integration tests"
