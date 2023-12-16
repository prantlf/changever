#!/bin/sh

set -e

test() {
  if [ "$2" != "" ]; then
    echo "----------------------------------------"
  fi
  echo "$1"
  echo "----------------------------------------"
}

test "help"
./changever -h

test "version" 1
./changever -V

echo "----------------------------------------"
echo "done"
