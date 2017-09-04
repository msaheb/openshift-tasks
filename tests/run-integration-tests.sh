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
  ret="$(curl -s -o /dev/null -w "%{http_code}" "$url")"
  if [ "$ret" != "$expected" ]; then
    echo "$url: Got HTTP Status code '$ret' instead of a '$expected' Status code."
    exit 1
  fi
}

runtest "$appurl/" 200
runtest "$appurl/demo/get-pod-name" 200
runtest "$appurl/blabla" 404

echo "Successfully passed integration tests"
