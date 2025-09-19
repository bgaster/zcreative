#!/bin/bash

ZAP_USE_OPENSSL=true
ZIG_BUILD_CMD="zig build -Doptimize=ReleaseFast"

if [ "$1" == "run" ]; then
    $ZIG_BUILD_CMD run
else
    $ZIG_BUILD_CMD
fi
