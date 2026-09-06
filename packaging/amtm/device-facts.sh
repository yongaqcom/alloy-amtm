#!/bin/sh

echo "productid=$(nvram get productid 2>/dev/null || echo unknown)"
uname -a
uname -m
cat /proc/cpuinfo
getconf GNU_LIBC_VERSION 2>/dev/null || true
/opt/bin/opkg print-architecture 2>/dev/null || true
mount
df -h /opt
if [ -r /proc/config.gz ]; then
    echo "/proc/config.gz is available; preserve it with the test report."
fi
for tool in curl tar sha256sum readlink; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo "$tool=$(command -v "$tool")"
    else
        echo "$tool=missing"
    fi
done
