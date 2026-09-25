#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/.."
LUA_BIN=""
for candidate in lua luajit; do
  if command -v "$candidate" >/dev/null 2>&1; then LUA_BIN="$candidate"; break; fi
done
if [ -z "$LUA_BIN" ]; then echo "No Lua interpreter found (tried lua, luajit)" >&2; exit 1; fi
for file in partycare.lua settings.lua src/*.lua tests/*.lua; do
  luac -p "$file"
done
"$LUA_BIN" tests/test_manual_dispatch.lua
