#!/bin/bash
set -u

cd "$(dirname "$0")/.."

for step in -2 -1 0 1 2 3 4 5
do
    echo "Testing dimming step $step"
    .build/SetDFRBrightness "$step" 1.0 3 &
    test_pid=$!
    sleep 1
    ioreg -r -c AppleARMBacklight -l -w 0 \
        | grep 'CurrentNits' \
        | tail -n 1
    wait "$test_pid"
done
