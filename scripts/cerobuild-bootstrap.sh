#!/bin/bash

# Steps to setup build:
# 1. Clone cerowrt repository
# 2. Setup feeds.conf
# 3. Setup new env/, pull from cerofiles
# 4. Install packages
# 5. Copy over .config

CEROWRT_URL="https://github.com/dtaht/cerowrt-next.git"
CEROFILES_URL="https://github.com/dtaht/cerofiles-next.git"
CEROWRT_REVISION="master"
CEROFILES_REVISION="cerowrt-next"
BUILD_DIR="${1:-$PWD/cerowrt-build}"
SOURCE_DIR="$BUILD_DIR/sources"


error()
{
    echo "$@" >&2
    exit 1
}

clone_repository()
{
    name="$1"
    src="$2"
    rev="$3"

    [ -d "$SOURCE_DIR/$name" ] || git clone "$src" "$SOURCE_DIR/$name" || error "Unable to clone repository for $name"
    pushd "$SOURCE_DIR/$name" && git fetch
    git checkout "$rev" || error "Unable to checkout $rev for $name"
    popd
}

update_env()
{
    pushd env
    if ! git remote | grep -q cerofiles; then
        git remote add cerofiles "$CEROFILES_URL"
    fi
    git fetch cerofiles && git merge --no-edit cerofiles/$CEROFILES_REVISION
    popd
}


[ -d "$BUILD_DIR" ] || mkdir -p "$BUILD_DIR" || error "Unable to create $BUILD_DIR"
[ -d "$SOURCE_DIR" ] || mkdir "$SOURCE_DIR" || error "Unable to create $SOURCE_DIR"

if [ ! -d "$BUILD_DIR/cerowrt" ]; then
    git clone "$CEROWRT_URL" "$BUILD_DIR/cerowrt" || error "Unable to clone main cerowrt repository"
fi

cd "$BUILD_DIR/cerowrt" && git fetch || error "Unable to fetch newest sources"
git checkout "$CEROWRT_REVISION" || error "Unable to checkout revision '$CEROWRT_REVISION'"
[ "$CEROWRT_REVISION" == "master" ] && git pull || error "Unable to pull"

[ -e dl ] || ln -s "$SOURCE_DIR" dl || error "Unable to link in source dir"

while read line; do
    clone_repository $line
done < feeds.source

echo "n" | ./scripts/env new "cero-$CEROWRT_REVISION" || echo "n" | ./scripts/env switch "cero-$CEROWRT_REVISION" || error "Unable to create env"

update_env

./scripts/feeds update || error "Couldn't update feed indexes"
./scripts/feeds uninstall $(cat env/override.list) || error "Couldn't uninstall overrides"
./scripts/feeds install $(cat env/override.list) || error "Couldn't install overrides"
./scripts/feeds install $(cat env/packages.list) || error "Couldn't install packages"

cp env/config-wndr3700v2 .config || error "Unable to copy .config"
make defconfig || error "Unable to run defconfig"

echo "Source tree is in $BUILD_DIR/cerowrt - Run 'make' to build."
