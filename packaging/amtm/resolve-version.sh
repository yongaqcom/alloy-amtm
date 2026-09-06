#!/bin/sh
set -eu

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 REF_TYPE REF_NAME UPSTREAM_VERSION_FILE" >&2
    exit 2
fi

REF_TYPE=$1
REF_NAME=$2
UPSTREAM_VERSION_FILE=$3

[ -f "$UPSTREAM_VERSION_FILE" ] || {
    echo "Upstream version file not found: $UPSTREAM_VERSION_FILE" >&2
    exit 1
}

upstream_version=$(sed 's/[[:space:]]*#.*//' "$UPSTREAM_VERSION_FILE" | tr -d '[:space:]')
if ! printf '%s\n' "$upstream_version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "Invalid upstream Alloy version: $upstream_version" >&2
    exit 1
fi

if [ "$REF_TYPE" = tag ]; then
    prefix="v${upstream_version}-amtm."
    case "$REF_NAME" in
        "$prefix"*) amtm_revision=${REF_NAME#"$prefix"} ;;
        *)
            echo "Release tag $REF_NAME must start with $prefix" >&2
            exit 1
            ;;
    esac
    case "$amtm_revision" in
        ''|*[!0-9]*|0*)
            echo "Release tag $REF_NAME must end with a positive AMTM revision" >&2
            exit 1
            ;;
    esac
fi

printf '%s\n' "$REF_NAME"
