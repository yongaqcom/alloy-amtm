# Alloy for Asuswrt-Merlin and AMTM

This repository builds a static ARM64 Grafana Alloy binary and packages it for
Entware's `/opt` filesystem. The initial supported router is the ASUS RT-BE88U
running Asuswrt-Merlin. Router support is isolated from the unmodified Alloy
source, which is pinned in the `upstream/` Git submodule.

## Requirements

- ASUS RT-BE88U with Asuswrt-Merlin
- AMTM and Entware installed on persistent USB storage mounted at `/opt`
- At least 800,000 KiB free under `/opt` so an update can coexist with the
  previous version until startup succeeds
- `curl`, `tar`, and `sha256sum` available (the installer reports a missing tool)

The executable is a pure-Go `linux/arm64` build with an ARMv8.0 baseline. It
doesn't depend on the router firmware's C library. The build omits the embedded
web UI and the embedded Beyla helper to reduce the artifact size. The local
HTTP endpoint still exposes health and metrics, but UI assets aren't included.

## Install

Run this from the router shell as `admin`:

```sh
curl -fsSL https://raw.githubusercontent.com/yongaqcom/alloy-amtm/main/packaging/amtm/install.sh -o /tmp/install-alloy
sh /tmp/install-alloy
```

The installer rejects unrecognized models and architectures. For development
only, `ALLOY_AMTM_SKIP_PLATFORM_CHECKS=1` bypasses those checks.

Installed paths:

```text
/opt/bin/alloy
/opt/bin/alloy-amtm
/opt/etc/alloy/config.alloy
/opt/etc/alloy/env
/opt/etc/init.d/S99alloy
/opt/lib/alloy/versions/<version>/alloy
/opt/var/lib/alloy
/opt/var/log/alloy/alloy.log
```

The default endpoint listens only on `127.0.0.1:12345`. Configuration and
state are preserved during updates and normal uninstall.

## Operate

```sh
alloy-amtm status
alloy-amtm validate
alloy-amtm restart
alloy-amtm logs
alloy-amtm update
alloy-amtm uninstall
```

Run `alloy-amtm` without arguments for an interactive AMTM-style menu.

Edit `/opt/etc/alloy/config.alloy` to add pipelines, then validate and restart.
The shipped configuration is deliberately minimal so installation is safe
before remote-write or Loki credentials have been configured.

## Support boundaries

The full Alloy component registry is present, but only basic host metrics,
file logs, Prometheus remote write, and OTLP forwarding are intended for the
initial router profile. These are not supported on the BE88U until tested on
its Merlin kernel:

- `beyla.ebpf` and `pyroscope.ebpf`
- systemd journal sources
- Docker and Kubernetes discovery
- collectors requiring systemd, udev, cgroups, or desktop/server `/sys` data

Use `prometheus.exporter.unix` collectors selectively. Router firmware exposes
a smaller and different `/proc` and `/sys` surface than a conventional Linux
distribution.

## Build and release

`.github/workflows/build-amtm.yml` cross-compiles on GitHub-hosted runners,
checks the ELF architecture and static linkage, validates the sample config
under ARM64 emulation, tests the BusyBox-compatible packaging scripts, and
uploads the tarball plus `SHA256SUMS`. Tags matching `v*-amtm.*` create a GitHub
Release.

Maintainers should follow the [upstream release tracking runbook](UPSTREAM.md)
when updating to a new Grafana Alloy release.

See [engineering findings and validation status](FINDINGS.md) for the evidence
behind the current design and the work that still requires a physical BE88U.

Before declaring another router supported, run the commands in
[`device-facts.sh`](../../packaging/amtm/device-facts.sh), test boot ordering,
and complete a 24-hour soak test on real hardware.
