#!/bin/sh

while :; do
    go build .
    ./epilogue &
    p=$!
    inotifyd - $(find -type d | grep -vE "imgs|.git" | xargs -I % echo %:w) | head -n0
    kill $p
done &

trap exit SIGTERM
wait $(jobs -p)
