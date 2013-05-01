#!/bin/bash

# Steps to setup build:
# 1. Clone cerowrt repository
# 2. Setup feeds.conf
# 3. Setup new env/, pull from cerofiles
# 4. Install packages
# 5. Copy over .config

CEROFILES_URL="https://github.com/dtaht/cerofiles-next.git"
CEROFILES_REVISION="cerofiles/cerowrt-next"

UPDATE=0
HEAD=0
SOURCE_DIR=./dl
UPDATE_ENV=1
UPDATE_PACKAGES=1
INSTALL_PACKAGES=1
UPDATE_CONFIG=1

usage()
{
    cat >&2 <<EOF
Usage: $0 [-uHEPIC] [-s <source dir>]

 -u:                Update package and files repositories to values specified
                    by currently checked out revision.

 -H:                Use branch HEADs for package and files repositories rather than
                    the commits specified by the config files in the current checkout.
                    (This may break the build in unexpected ways.)

 -E:                Do not update the env/ directory from cerofiles.

 -P:                Do not update the package feed source repositories.

 -I:                Do not (re)install the packages listed in packages.list and
                    override.list in cerofiles.

 -C:                Do not update (override) .config from the cerofiles config file.

 -s <source dir>:   Specify source directory to keep package repositories in.
                    Default: $SOURCE_DIR
EOF
    exit 1;
}

error()
{
    echo "--- $@" >&2
    exit 1
}


clone_repository()
{
    name="$1"
    src="$2"

    [ -d "$SOURCE_DIR/$name" ] || git clone "$src" "$SOURCE_DIR/$name" || error "Unable to clone repository for $name"
} > /dev/null

checkout_rev()
{
    name="$1"
    rev="$2"

    if [ "$HEAD" == "1" ]; then
        ( cd "$SOURCE_DIR/$name" && git checkout master && git pull ) || error "Unable to checkout master of repository $name"
    else
        ( cd "$SOURCE_DIR/$name" && git fetch && git checkout "$rev" ) || error "Unable to checkout $rev for $name"
    fi
}

update_env()
{
    [ -d env ] || echo n | ./scripts/env new cerobuild
    (cd env
    if ! git remote | grep -q cerofiles; then
        git remote add cerofiles "$CEROFILES_URL"
    fi
    git fetch cerofiles && git merge --no-edit $CEROFILES_REVISION || error "Unable to merge cerofiles")
}

add_feed()
{
    name=$1
    target=$(realpath -ms --relative-to feeds/ "$SOURCE_DIR/$name")
    echo src-link $name $target >> .feeds.conf.cerobuild
}

while getopts "uhHs:EPIC" opt; do
    case $opt in
        u) UPDATE=1;;
        h) usage;;
        H) HEAD=1;;
        s) SOURCE_DIR=$OPTARG;;
        E) UPDATE_ENV=0;;
        P) UPDATE_PACKAGES=0;;
        I) INSTALL_PACKAGES=0;;
        C) UPDATE_CONFIG=0;;
    esac
done


if [ -f cerofiles.revision ]; then
    [ "$HEAD" == "0" ] && CEROFILES_REVISION=$(<cerofiles.revision)
else
    echo "--- Warning: No cerofiles.revision file found; using tip of 'cerowrt-next' branch."
fi


[ -e "$SOURCE_DIR" ] || mkdir "$SOURCE_DIR" || error "Unable to create $SOURCE_DIR"

if [ "$UPDATE_PACKAGES" == "1" ]; then
    echo "--- Updating packages..."
    echo -n > .feeds.conf.cerobuild
    while read name src rev; do
        [ -d "$SOURCE_DIR/$name" ] || clone_repository $name $src
        checkout_rev $name $rev
        add_feed $name
    done < feeds.source
    ./scripts/feeds update || error "Couldn't update feed indexes"
    [ -e "feeds.conf" ] || ln -s .feeds.conf.cerobuild feeds.conf
fi

if [ "$UPDATE_ENV" == "1" ]; then
    echo "--- Updating env from cerofiles..."
    update_env
fi

if [ "$INSTALL_PACKAGES" == "1" ]; then
    echo "--- Installing packages..."
    ./scripts/feeds uninstall $(cat env/override.list) || error "Couldn't uninstall overrides"
    ./scripts/feeds install $(cat env/override.list) || error "Couldn't install overrides"
    ./scripts/feeds install $(cat env/packages.list) || error "Couldn't install packages"
fi

if [ "$UPDATE_CONFIG" == "1" ]; then
    echo "--- Copying .config and running 'make defconfig'..."
    cp env/config-wndr3700v2 .config || error "Unable to copy .config"
    make defconfig || error "Unable to run defconfig"
fi

echo "--- Build updated. Run make to build."
