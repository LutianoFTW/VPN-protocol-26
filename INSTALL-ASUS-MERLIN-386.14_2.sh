#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec "$SCRIPT_DIR/scripts/install-asus-merlin-386.14_2-full.sh" "$@"
