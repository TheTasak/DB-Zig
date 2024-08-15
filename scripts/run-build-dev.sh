#!/usr/bin/env bash

time zig build && ./zig-out/bin/zig-db "$@"
