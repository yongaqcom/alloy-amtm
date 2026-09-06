#!/bin/sh
set -eu

ROOT=$(CDPATH='' cd "$(dirname "$0")/../.." && pwd)
TEST_TMP=${TEST_TMP:-$ROOT/.tmp/amtm-tests}
PAYLOAD="$TEST_TMP/payload"
PREFIX="$TEST_TMP/opt"

cleanup() {
    if [ -x "$PREFIX/etc/init.d/S99alloy" ]; then
        ALLOY_AMTM_PREFIX="$PREFIX" "$PREFIX/etc/init.d/S99alloy" stop >/dev/null 2>&1 || true
    fi
    rm -rf "$TEST_TMP"
}
trap cleanup EXIT HUP INT TERM
cleanup
mkdir -p "$PAYLOAD" "$PREFIX/bin"

for file in alloy-amtm S99alloy config.alloy env install.sh; do
    cp "$ROOT/packaging/amtm/$file" "$PAYLOAD/$file"
done
printf '%s\n' 'v0.0.0-test.1' >"$PAYLOAD/VERSION"

cat >"$PAYLOAD/alloy" <<'EOF'
#!/bin/sh
case "${1:-}" in
    validate) exit 0 ;;
    --version) echo "alloy test"; exit 0 ;;
    run) trap 'exit 0' TERM INT; while :; do sleep 1; done ;;
    *) exit 2 ;;
esac
EOF
chmod 0755 "$PAYLOAD/alloy"

ALLOY_AMTM_PREFIX="$PREFIX" ALLOY_AMTM_SKIP_PLATFORM_CHECKS=1 \
    sh "$PAYLOAD/install.sh" --from-dir "$PAYLOAD"

[ -L "$PREFIX/bin/alloy" ]
[ -x "$PREFIX/bin/alloy-amtm" ]
[ -f "$PREFIX/etc/alloy/config.alloy" ]
ALLOY_AMTM_PREFIX="$PREFIX" "$PREFIX/bin/alloy-amtm" status
ALLOY_AMTM_PREFIX="$PREFIX" "$PREFIX/bin/alloy-amtm" validate

printf '%s\n' '# preserved' >>"$PREFIX/etc/alloy/config.alloy"
ALLOY_AMTM_PREFIX="$PREFIX" ALLOY_AMTM_SKIP_PLATFORM_CHECKS=1 \
    sh "$PAYLOAD/install.sh" --from-dir "$PAYLOAD"
grep -q '# preserved' "$PREFIX/etc/alloy/config.alloy"

ALLOY_AMTM_PREFIX="$PREFIX" "$PREFIX/bin/alloy-amtm" uninstall
[ ! -e "$PREFIX/bin/alloy" ]
[ -f "$PREFIX/etc/alloy/config.alloy" ]

echo "AMTM packaging tests passed."
