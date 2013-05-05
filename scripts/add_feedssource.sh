#!/bin/bash

SOURCE_DIR=./dl

NAME="$1"
SRC="$2"

die()
{
    echo "$@" >&2
    exit 1
}

[ -n "$NAME" -a -n "$SRC" ] || die "Usage: $0 <name> <src>."

[ -f feeds.source ] || die "Can't find feeds.source."

grep -q "^$NAME" feeds.source && die "Feed '$NAME' already exists in feeds.source."

[ -d "$SOURCE_DIR/$NAME" ] || git clone "$SRC" "$SOURCE_DIR/$NAME" || die "Unable to clone '$SRC' and '$SOURCE_DIR/$NAME' not found."

rev=$( cd "$SOURCE_DIR/$NAME" && git rev-parse --verify HEAD )

echo $NAME $SRC $rev >> feeds.source
