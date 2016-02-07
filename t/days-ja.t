#!/bin/sh
echo "1..1"
basedir=`dirname $0`/..
jq=$basedir/local/bin/jq

test() {
  (cat $basedir/data/days-ja.json | $jq -e "$2" > /dev/null && echo "ok $1") || echo "not ok $1"
}

test 1 '.["01-05"].birthdays | map(select(.date_gregorian == "0766-01-05")) | map(select(.wref == "アリー・リダー")) | length > 0 | not | not'
