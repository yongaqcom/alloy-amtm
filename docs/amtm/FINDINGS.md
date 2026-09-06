# Engineering findings

This document records what was learned while creating the initial Alloy AMTM
distribution. It separates results verified by automation from assumptions
that still require an ASUS RT-BE88U running Asuswrt-Merlin.

Last updated: 2026-09-06

## Summary

Grafana Alloy can be cross-compiled as a static Linux ARM64 executable without
CGO. That removes the router firmware's C library and dynamic loader from the
compatibility boundary. The resulting full Alloy executable is large, but it
can be packaged into a release archive suitable for persistent Entware storage.

The initial implementation has passed native build checks, ARM64 emulation,
configuration validation, shell linting, and installer lifecycle tests. It has
not yet been run on a physical BE88U. Hardware support should therefore be
treated as provisional until the real-device tests in this document pass.

## Findings at a glance

| Finding | Status | Evidence | Remaining work |
| --- | --- | --- | --- |
| Alloy builds for `linux/arm64` with `CGO_ENABLED=0` | Verified | Local container build and GitHub Actions | Repeat for each upstream release |
| The executable is static AArch64 | Verified | `file` and `readelf` checks in CI | Confirm it starts on the BE88U kernel |
| Alloy starts and validates the sample configuration under ARM64 emulation | Verified | `qemu-aarch64-static` CI smoke test | Test router `/proc`, `/sys`, and networking |
| Packaging scripts are POSIX/BusyBox-oriented | Partially verified | ShellCheck and lifecycle tests under `/bin/sh` | Run with the BE88U's exact BusyBox build |
| Updates preserve configuration and can roll back a failed start | Partially verified | Fake-binary lifecycle test | Force an upgrade failure on a router |
| Entware init scripts start after `/opt` is available | Assumed | Conventional `/opt/etc/init.d/S99alloy` layout | Verify cold-boot ordering on Merlin |
| RT-BE88U is suitable for ARM64 builds | Assumed | Router family information and intended Entware target | Capture `uname`, CPU, kernel, and opkg facts |
| Full Alloy is operationally affordable on a router | Unknown | Build size is known; runtime usage isn't | Measure RSS, CPU, storage I/O, and heat |
| The addon is listed in AMTM itself | Not implemented | A standalone AMTM-style manager is included | Coordinate catalog inclusion with AMTM maintainers |

## Hardware and operating environment

ASUS documents the RT-BE88U as having a quad-core 2.6 GHz CPU and 2 GiB RAM.
The product page is the authoritative source for those published specifications:

- [ASUS RT-BE88U product page](https://www.asus.com/networking-iot-servers/wifi-routers/asus-gaming-routers/rt-be88u/)

The exact CPU identity, ARM feature level, Merlin kernel version, libc, and
Entware package architecture haven't been captured from the target device.
The build therefore uses the conservative Go ARMv8.0 baseline:

```text
GOOS=linux
GOARCH=arm64
GOARM64=v8.0
CGO_ENABLED=0
```

Run [`device-facts.sh`](../../packaging/amtm/device-facts.sh) on the router and
attach its non-secret output to the first hardware test report. At minimum,
confirm:

- `nvram get productid` returns `RT-BE88U`.
- `uname -m` reports `aarch64` or an equivalent ARM64 value.
- Entware reports a compatible AArch64 package architecture.
- `/opt` is persistent, executable, and has at least 800,000 KiB free.
- The kernel implements the system calls required by the selected Go release.
- `curl`, CA certificates, `tar`, `sha256sum`, and `readlink` behave as expected.

## Build findings

The checked-in source was initially imported from `grafana/alloy` commit
`0dffb9f2829cf6ee5e527568e22a5ba82cb5dd5f`. The exact source base is tracked
in [`UPSTREAM_VERSION`](../../packaging/amtm/UPSTREAM_VERSION).

The dedicated workflow builds `collector/` directly instead of using the full
upstream packaging target. This has two useful effects for the router build:

1. It doesn't embed the Alloy web UI. HTTP health and metrics endpoints remain,
   but browser UI assets aren't present.
2. It doesn't download and embed the Beyla subprocess. `beyla.ebpf` is outside
   the initial support boundary.

The initial local build produced these approximate sizes:

```text
Static executable: 362 MiB
Compressed package: 90 MiB
Published v0.1.0-amtm.1 archive: 93,832,483 bytes
```

The size comes primarily from shipping Alloy's full component registry and its
dependency graph. Upstream doesn't currently provide a supported way to select
an arbitrary subset at build time; build-time composability is being discussed
in [grafana/alloy#6428](https://github.com/grafana/alloy/issues/6428).

Do not maintain a large component-removal patch until real-device measurements
show that the full build is unusable. A lean build would reduce storage and
possibly memory pressure, but would increase divergence and make every upstream
update harder to audit.

## Runtime and storage findings

Router flash isn't an appropriate location for the executable, Alloy state, or
logs. The package uses the persistent Entware volume:

```text
/opt/lib/alloy/versions/<version>/alloy
/opt/etc/alloy/config.alloy
/opt/var/lib/alloy
/opt/var/log/alloy/alloy.log
```

The installer keeps the previous version while validating and starting the new
one. Because two 362 MiB executables can temporarily coexist, it requires at
least 800,000 KiB free under `/opt`.

Conservative initial runtime defaults are:

```text
GOMEMLIMIT=384MiB
GOMAXPROCS=2
GODEBUG=netdns=go
ALLOY_HTTP_LISTEN_ADDR=127.0.0.1:12345
```

These values are safety-oriented starting points, not performance findings.
They must be tuned from measured RSS, garbage-collection activity, CPU load,
telemetry volume, and router responsiveness.

The current init script writes one log file and doesn't yet configure external
rotation. Confirm whether the installed Entware environment provides a suitable
`logrotate` or logger facility before enabling verbose pipelines. Unbounded log
growth is a release blocker.

## Component support findings

The binary contains the full registry, but presence isn't the same as support.
The initial profile is intended for:

- basic `prometheus.exporter.unix` collectors that work against the router's
  actual `/proc` and `/sys`
- Prometheus scraping, relabeling, and remote write
- file-based log ingestion, processing, and Loki write
- OTLP receive, process, and export paths that pass device testing

The following are unsupported until explicitly tested:

- `beyla.ebpf` and `pyroscope.ebpf`
- systemd journal sources
- Docker and Kubernetes discovery
- collectors requiring systemd, udev, cgroups, BTF, or a conventional server
  filesystem layout
- cloud and database integrations not covered by router tests

Grafana's Linux permissions guidance notes that components may need access to
`/proc`, `/sys`, journals, application logs, or elevated kernel capabilities:

- [Alloy Linux access and permissions](https://grafana.com/docs/alloy/latest/access_permissions/linux/)
- [Beyla eBPF requirements](https://grafana.com/docs/alloy/latest/reference/components/beyla/beyla.ebpf/)

Asuswrt-Merlin's kernel and userspace aren't equivalent to a general-purpose
systemd Linux distribution. Enable Unix exporter collectors individually and
record failures instead of relying on conventional defaults.

## Installer and update findings

The lifecycle test verifies that a synthetic Alloy process can be installed,
started, queried, stopped, reinstalled, and uninstalled while preserving its
configuration. The implementation also validates a new binary against the
existing configuration before accepting it and restores the previous symlink
if startup fails.

Release archives are checked against `SHA256SUMS`. This detects corruption, but
the checksum and archive are currently downloaded from the same GitHub Release.
It doesn't protect against a compromised repository or release credential. A
future hardening step should sign a manifest with an offline key and verify it
with tooling known to be available on Entware.

Normal uninstall preserves configuration, state, and logs. `--purge` removes
them. The script removes only paths owned by this distribution and doesn't
rewrite shared AMTM or `/jffs/scripts` files.

## CI evidence

The initial release workflow succeeded and published the ARM64 archive and
checksum:

- [Initial release](https://github.com/yongaqcom/alloy-amtm/releases/tag/v0.1.0-amtm.1)
- [Initial release build](https://github.com/yongaqcom/alloy-amtm/actions/runs/34059984602)

CI verifies:

- ShellCheck for all router shell scripts
- install, reinstall, service control, configuration preservation, and uninstall
- ARM64 static cross-compilation
- ELF machine type and absence of a dynamic program interpreter
- `--version` and sample configuration validation through QEMU
- archive construction and checksum publication

CI doesn't verify physical-router boot behavior, kernel interfaces, sustained
resource use, USB reliability, or network throughput.

## Required BE88U validation

Complete these before changing support status from provisional:

1. Capture device facts and firmware version.
2. Install `v0.1.0-amtm.1` on a dedicated Entware volume.
3. Validate and start the minimal configuration.
4. Reboot repeatedly and confirm Alloy starts only after `/opt` is mounted.
5. Test each claimed metrics, logs, remote-write, and OTLP path separately.
6. Record idle and loaded RSS, CPU, temperature, storage writes, and archive
   extraction time.
7. Test invalid configuration, corrupt download, disk-full behavior, failed
   startup, rollback, reinstall, normal uninstall, and purge.
8. Run representative telemetry for at least 24 hours while checking routing,
   Wi-Fi, NAT, and management responsiveness.

Record firmware and configuration versions with every result. A passing test
on one Merlin release doesn't guarantee compatibility with another kernel or
Entware toolchain.

## Open issues and next decisions

- Decide whether actual AMTM catalog inclusion is desired after the standalone
  addon is stable; that requires coordination outside this repository.
- Add bounded log rotation before recommending verbose file-log pipelines.
- Determine which Unix exporter collectors are safe and useful on the BE88U.
- Measure whether the full 362 MiB binary and its runtime RSS are acceptable.
- Add signed release metadata if a practical verifier is available in Entware.
- Replace the provisional upstream `main` snapshot with the next final Alloy
  release by following [`UPSTREAM.md`](UPSTREAM.md).
