#!/bin/sh
set -eu

REPOSITORY=${ALLOY_AMTM_REPOSITORY:-yongaqcom/alloy-amtm}
PREFIX=${ALLOY_AMTM_PREFIX:-/opt}
ASSET=alloy-amtm-linux-arm64.tar.gz
VERSION=latest
ARCHIVE=
SOURCE_DIR=
MODE=install
PURGE=0

usage() {
    cat <<'EOF'
Usage: install.sh [--version VERSION] [--archive FILE]
       install.sh --from-dir DIRECTORY
       install.sh --uninstall [--purge]

Environment:
  ALLOY_AMTM_PREFIX=/opt
  ALLOY_AMTM_REPOSITORY=yongaqcom/alloy-amtm
  ALLOY_AMTM_SKIP_PLATFORM_CHECKS=1  (development only)
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --version) [ "$#" -ge 2 ] || { usage >&2; exit 2; }; VERSION=$2; shift 2 ;;
        --archive) [ "$#" -ge 2 ] || { usage >&2; exit 2; }; ARCHIVE=$2; shift 2 ;;
        --from-dir) [ "$#" -ge 2 ] || { usage >&2; exit 2; }; SOURCE_DIR=$2; shift 2 ;;
        --uninstall) MODE=uninstall; shift ;;
        --purge) PURGE=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

check_platform() {
    [ "${ALLOY_AMTM_SKIP_PLATFORM_CHECKS:-0}" = 1 ] && return 0
    arch=$(uname -m)
    case "$arch" in aarch64|arm64) ;; *) echo "Unsupported architecture: $arch (expected aarch64)." >&2; exit 1 ;; esac
    command -v nvram >/dev/null 2>&1 || { echo "nvram not found; Asuswrt-Merlin is required." >&2; exit 1; }
    model=$(nvram get productid 2>/dev/null || true)
    [ "$model" = RT-BE88U ] || { echo "Unsupported router: ${model:-unknown} (expected RT-BE88U)." >&2; exit 1; }
    [ -x "$PREFIX/bin/opkg" ] || { echo "Entware is required under $PREFIX. Install it from AMTM first." >&2; exit 1; }
}

uninstall_alloy() {
    if [ -x "$PREFIX/etc/init.d/S99alloy" ]; then
        "$PREFIX/etc/init.d/S99alloy" stop || true
    fi
    rm -f "$PREFIX/bin/alloy" "$PREFIX/bin/alloy-amtm" "$PREFIX/etc/init.d/S99alloy"
    rm -rf "$PREFIX/lib/alloy" "$PREFIX/share/alloy-amtm"
    if [ "$PURGE" -eq 1 ]; then
        rm -rf "$PREFIX/etc/alloy" "$PREFIX/var/lib/alloy" "$PREFIX/var/log/alloy"
        echo "Alloy and its configuration, state, and logs were removed."
    else
        echo "Alloy was removed. Configuration and state were preserved."
    fi
}

if [ "$MODE" = uninstall ]; then
    uninstall_alloy
    exit 0
fi

check_platform

mkdir -p "$PREFIX"
free_kb=$(df -Pk "$PREFIX" | awk 'NR == 2 { print $4 }')
case "$free_kb" in *[!0-9]*|'') echo "Unable to determine free space under $PREFIX." >&2; exit 1 ;; esac
if [ "$free_kb" -lt 800000 ]; then
    echo "At least 800000 KiB free under $PREFIX is required; found $free_kb KiB." >&2
    exit 1
fi

for tool in tar sha256sum; do
    command -v "$tool" >/dev/null 2>&1 || { echo "$tool is required." >&2; exit 1; }
done

WORK_DIR="${TMPDIR:-/tmp}/alloy-amtm-install.$$"
mkdir -p "$WORK_DIR"
trap 'rm -rf "$WORK_DIR"' EXIT HUP INT TERM

if [ -n "$SOURCE_DIR" ]; then
    payload=$SOURCE_DIR
else
    if [ -n "$ARCHIVE" ]; then
        cp "$ARCHIVE" "$WORK_DIR/$ASSET"
    else
        command -v curl >/dev/null 2>&1 || { echo "curl is required." >&2; exit 1; }
        if [ "$VERSION" = latest ]; then
            base_url="https://github.com/$REPOSITORY/releases/latest/download"
        else
            case "$VERSION" in *[!A-Za-z0-9._-]*|'') echo "Invalid version: $VERSION" >&2; exit 2 ;; esac
            base_url="https://github.com/$REPOSITORY/releases/download/$VERSION"
        fi
        echo "Downloading $ASSET from $REPOSITORY..."
        curl -fL "$base_url/$ASSET" -o "$WORK_DIR/$ASSET"
        curl -fsSL "$base_url/SHA256SUMS" -o "$WORK_DIR/SHA256SUMS"
        expected=$(awk -v name="$ASSET" '$2 == name || $2 == "*" name { print $1; exit }' "$WORK_DIR/SHA256SUMS")
        [ -n "$expected" ] || { echo "No checksum found for $ASSET." >&2; exit 1; }
        actual=$(sha256sum "$WORK_DIR/$ASSET" | awk '{print $1}')
        [ "$actual" = "$expected" ] || { echo "Artifact checksum verification failed." >&2; exit 1; }
    fi
    mkdir "$WORK_DIR/payload"
    tar -xzf "$WORK_DIR/$ASSET" -C "$WORK_DIR/payload"
    payload=$WORK_DIR/payload
fi

for file in alloy alloy-amtm S99alloy config.alloy env VERSION install.sh; do
    [ -f "$payload/$file" ] || { echo "Invalid package: missing $file" >&2; exit 1; }
done

release_version=$(tr -d '\r\n' <"$payload/VERSION")
case "$release_version" in *[!A-Za-z0-9._+-]*|'') echo "Invalid package version." >&2; exit 1 ;; esac

version_dir="$PREFIX/lib/alloy/versions/$release_version"
old_target=$(readlink "$PREFIX/bin/alloy" 2>/dev/null || true)

mkdir -p "$version_dir" "$PREFIX/bin" "$PREFIX/etc/alloy" "$PREFIX/etc/init.d" \
    "$PREFIX/share/alloy-amtm" "$PREFIX/var/lib/alloy" "$PREFIX/var/log/alloy" "$PREFIX/var/run"

if [ -x "$PREFIX/etc/init.d/S99alloy" ]; then
    "$PREFIX/etc/init.d/S99alloy" stop || true
fi

cp "$payload/alloy" "$version_dir/alloy"
cp "$payload/alloy-amtm" "$PREFIX/bin/alloy-amtm"
cp "$payload/S99alloy" "$PREFIX/etc/init.d/S99alloy"
cp "$payload/install.sh" "$PREFIX/share/alloy-amtm/install.sh"
cp "$payload/VERSION" "$PREFIX/share/alloy-amtm/VERSION"
chmod 0755 "$version_dir/alloy" "$PREFIX/bin/alloy-amtm" \
    "$PREFIX/etc/init.d/S99alloy" "$PREFIX/share/alloy-amtm/install.sh"

if [ ! -f "$PREFIX/etc/alloy/config.alloy" ]; then
    cp "$payload/config.alloy" "$PREFIX/etc/alloy/config.alloy"
    chmod 0600 "$PREFIX/etc/alloy/config.alloy"
fi
if [ ! -f "$PREFIX/etc/alloy/env" ]; then
    cp "$payload/env" "$PREFIX/etc/alloy/env"
    chmod 0600 "$PREFIX/etc/alloy/env"
fi

ln -sfn "$version_dir/alloy" "$PREFIX/bin/alloy"

if ! "$PREFIX/bin/alloy" validate "$PREFIX/etc/alloy/config.alloy"; then
    echo "The new binary rejected the existing configuration; rolling back." >&2
    if [ -n "$old_target" ]; then ln -sfn "$old_target" "$PREFIX/bin/alloy"; else rm -f "$PREFIX/bin/alloy"; fi
    exit 1
fi

if ! "$PREFIX/etc/init.d/S99alloy" start; then
    echo "The new version failed to start; rolling back." >&2
    if [ -n "$old_target" ]; then
        ln -sfn "$old_target" "$PREFIX/bin/alloy"
        "$PREFIX/etc/init.d/S99alloy" start || true
    else
        rm -f "$PREFIX/bin/alloy"
    fi
    exit 1
fi

echo "Installed Alloy $release_version. Run: $PREFIX/bin/alloy-amtm status"
