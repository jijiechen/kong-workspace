#!/bin/bash


set -x 


BASE_DIR=build

echo "Extracting files..."
ARCH='amd64'
ARTIFACT=$(find $BASE_DIR/distributions/out/kuma-*-linux-$ARCH.tar.gz)
if [[ "$ARTIFACT" == "" ]]; then
    echo "Could not find built artifact for linux($ARCH)."              
    exit 1
fi

mkdir $BASE_DIR/distributions/artifacts
tar -xzf $ARTIFACT -C $BASE_DIR/distributions/artifacts

SRC_DIR=$(find build/distributions/artifacts/*/bin -type d)
DEST_DIR=$BASE_DIR/artifacts-linux-$ARCH
for BIN in $(ls $SRC_DIR); do
    mkdir -p $DEST_DIR/$BIN
    cp $SRC_DIR/$BIN $DEST_DIR/$BIN/
done