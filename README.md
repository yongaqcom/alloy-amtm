# Alloy for Asuswrt-Merlin and AMTM

This repository packages [Grafana Alloy](https://github.com/grafana/alloy) for
Asuswrt-Merlin routers managed with AMTM. The first supported target is the
ASUS RT-BE88U (`linux/arm64`).

The repository intentionally contains only the downstream AMTM integration.
The unmodified Alloy source is pinned as the `upstream/` Git submodule.

## Clone

```sh
git clone --recurse-submodules https://github.com/yongaqcom/alloy-amtm.git
cd alloy-amtm
```

For an existing clone, initialize the source checkout with:

```sh
git submodule update --init --recursive
```

## Layout

- `upstream/` - pinned, unmodified `grafana/alloy` source
- `packaging/amtm/` - installer, service, configuration, and package builder
- `tests/amtm/` - downstream packaging tests
- `.github/workflows/build-amtm.yml` - static ARM64 build and release workflow
- `docs/amtm/` - installation notes, engineering findings, and update runbook

See the [AMTM installation guide](docs/amtm/README.md) for installation and
operation. Maintainers should use the
[upstream update runbook](docs/amtm/UPSTREAM.md) when changing the pinned Alloy
version.
