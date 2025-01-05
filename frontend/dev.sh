#!/bin/sh

npm install
npm run dev -- --host 0.0.0.0 &

trap exit SIGTERM
wait $(jobs -p)
