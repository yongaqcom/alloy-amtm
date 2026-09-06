#!/bin/sh
set -eu

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 ALLOY_BINARY VERSION OUTPUT_DIRECTORY" >&2
    exit 2
fi

ALLOY_BINARY=$1
VERSION=$2
OUTPUT=$3
ROOT=$(CDPATH='' cd "$(dirname "$0")/../.." && pwd)
STAGE="$OUTPUT/stage"
ASSET="$OUTPUT/alloy-amtm-linux-arm64.tar.gz"

rm -rf "$STAGE"
mkdir -p "$STAGE"
cp "$ALLOY_BINARY" "$STAGE/alloy"
for file in alloy-amtm S99alloy config.alloy env install.sh; do
    cp "$ROOT/packaging/amtm/$file" "$STAGE/$file"
done
printf '%s\n' "$VERSION" >"$STAGE/VERSION"
chmod 0755 "$STAGE/alloy" "$STAGE/alloy-amtm" "$STAGE/S99alloy" "$STAGE/install.sh"

tar -czf "$ASSET" -C "$STAGE" alloy alloy-amtm S99alloy config.alloy env VERSION install.sh
(cd "$OUTPUT" && sha256sum "$(basename "$ASSET")" >SHA256SUMS)
